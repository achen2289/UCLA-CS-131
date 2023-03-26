% HELPERS


% transpose method taken from here
% https://stackoverflow.com/questions/4280986/how-to-transpose-a-matrix-in-prolog

transpose([], []).
transpose([F|Fs], Ts) :-
    transpose(F, [F|Fs], Ts).
transpose([], _, []).
transpose([_|Rs], Ms, [Ts|Tss]) :-
        lists_firsts_rests(Ms, Ts, Ms1),
        transpose(Rs, Ms1, Tss).
lists_firsts_rests([], [], []).
lists_firsts_rests([[F|Os]|Rest], [F|Fs], [Os|Oss]) :-
        lists_firsts_rests(Rest, Fs, Oss).

rev_2D_list([], []).
rev_2D_list([LH | LT], [RH | RT]) :-
    reverse(LH, RH),
    rev_2D_list(LT, RT).


% ntower


ntower(N, T, C) :- 
    N >= 0,

    C = counts(TOP, BOTTOM, LEFT, RIGHT),
    length(TOP, N),
    length(BOTTOM, N),
    length(LEFT, N),
    length(RIGHT, N),

    fd_valid_rows(N, T),
    fd_valid_cols(N, T),

    fd_valid_counts(N, T, LEFT),

    rev_2D_list(T, TR),
    fd_valid_counts(N, TR, RIGHT),

    transpose(T, TRANS),
    fd_valid_cols(N, TRANS),

    fd_valid_counts(N, TRANS, TOP),

    rev_2D_list(TRANS, TRANSR),
    fd_valid_counts(N, TRANSR, BOTTOM),

    maplist(fd_labeling, T).

fd_valid_rows(R, T) :-
    length(T, R).

fd_valid_cols(_, []).
fd_valid_cols(C, [H | T]) :-
    length(H, C),
    fd_domain(H, 1, C),
    fd_all_different(H),
    fd_valid_cols(C, T).

fd_valid_counts(_, [], []).
fd_valid_counts(N, [TH | TT], [CH | CT]) :-
    fd_valid_ct_row(TH, 0, 0, CH),
    fd_valid_counts(N, TT, CT).

fd_valid_ct_row([], VIS, _, C) :-
    C #= VIS.
fd_valid_ct_row([RH | RT], VIS, MAX, C) :-
    RH #> MAX,
    VIS1 #= VIS+1,
    fd_valid_ct_row(RT, VIS1, RH, C).
fd_valid_ct_row([RH | RT], VIS, MAX, C) :-
    RH #< MAX,
    fd_valid_ct_row(RT, VIS, MAX, C).


% plain_ntower


plain_ntower(N, T, C) :- 
    N >= 0,
    generate_N_list(N, NLST),

    C = counts(TOP, BOTTOM, LEFT, RIGHT),

    valid_dims(N, N, T),
    valid_dims(4, N, [TOP, BOTTOM, LEFT, RIGHT]),

    valid_rows_and_counts(NLST, T, LEFT),

    rev_2D_list(T, TR),
    valid_rows_and_counts(NLST, TR, RIGHT),

    transpose(T, TRANS),

    valid_rows_and_counts(NLST, TRANS, TOP),

    rev_2D_list(TRANS, TRANSR),
    valid_rows_and_counts(NLST, TRANSR, BOTTOM).

generate_N_list(0, []).
generate_N_list(1, [1]).
generate_N_list(N, [N | LT]) :-
    N > 1,
    N1 is N-1,
    generate_N_list(N1, LT).

valid_dims(R, C, T) :-
    valid_row_dim(R, T),
    valid_col_dim(C, T).

valid_row_dim(R, T) :-
    length(T, R).

valid_col_dim(_, []).
valid_col_dim(C, [H | T]) :-
    length(H, C),
    valid_col_dim(C, T).

valid_rows_and_counts(_, [], []).
valid_rows_and_counts(NLST, [TH | TT], [CH | CT]) :-
    valid_row(NLST, TH),
    valid_ct_row(TH, 0, 0, CH),
    valid_rows_and_counts(NLST, TT, CT).

valid_row(NLST, X) :-
    permutation(NLST, X).

valid_ct_row([], VIS, _, C) :-
    C = VIS.
valid_ct_row([RH | RT], VIS, MAX, C) :-
    RH > MAX,
    VIS1 is VIS+1,
    valid_ct_row(RT, VIS1, RH, C).
valid_ct_row([RH | RT], VIS, MAX, C) :-
    RH < MAX,
    valid_ct_row(RT, VIS, MAX, C).


% speedup


speedup(RATIO) :-
    plain_ntower_time(PLAIN_CPU_TIME),
    ntower_time(FD_CPU_TIME),
    RATIO is PLAIN_CPU_TIME / FD_CPU_TIME.

plain_ntower_time(PLAIN_CPU_TIME) :-
    statistics(cpu_time, [_, _]),
    plain_ntower(5, _T, 
        counts(
            [4, 4, 2, 2, 1],
            [2, 1, 3, 2, 4],
            [5, 3, 3, 1, 2],
            [1, 2, 2, 3, 3])
    ),
    statistics(cpu_time, [_, DELTA]),
    PLAIN_CPU_TIME is DELTA.

ntower_time(FD_CPU_TIME) :-
    statistics(cpu_time, [_, _]),
    ntower(5, _T, 
        counts(
            [4, 4, 2, 2, 1],
            [2, 1, 3, 2, 4],
            [5, 3, 3, 1, 2],
            [1, 2, 2, 3, 3])
    ),
    statistics(cpu_time, [_, DELTA]),
    FD_CPU_TIME is DELTA.


% ambiguous


ambiguous(N, C, T1, T2) :-
    ntower(N, T1, C),
    ntower(N, T2, C),
    T1 \= T2.


/*
Refactored code to improve efficiency and removed or refactored the rules below.

my_jank_transpose(_, _, []).
my_jank_transpose(N, M, [TH | TT]) :-
    get_col_N(N, M, MN),
    equal(MN, TH),
    my_jank_transpose(N+1, M, TT).
my_jank_transpose_N(N, M, T) :-
    length(T, N),
    my_jank_transpose(1, M, T).

get_row_N(1, [H | _], H).
get_row_N(N, [_ | T], Mn) :-
    N1 is N-1,
    get_row_N(N1, T, Mn).

get_col_N(_, [], []).
get_col_N(N, [H | T], [HTn | TTn]) :-
    get_row_N(N, H, HTn),
    get_col_N(N, T, TTn).

equal(Mn, Tn) :-
    Mn = Tn.

valid_rows(_, []).
valid_rows(NLST, [X | T]) :-
    valid_row(NLST, X),
    valid_rows(NLST, T).

valid_cts(MAT, TRP, [C1, C2, C3, C4]) :-
    rev_2D_list(MAT, MATR),
    rev_2D_list(TRP, TRPR),
    valid_ct_rows(TRP, C1),
    valid_ct_rows(TRPR, C2),
    valid_ct_rows(MAT, C3),
    valid_ct_rows(MATR, C4).
    
valid_ct_rows([], []).
valid_ct_rows([TH | TT], [CH | CT]) :-
    VIS is 0,
    valid_ct_row(TH, VIS, 0, CH),
    valid_ct_rows(TT, CT).

generate_list_range(N, N, [N]).
generate_list_range(L, H, [L | LT]) :-
    L =< H,
    N is L+1,
    generate_list_range(N, H, LT).

subsequence([], _).   
subsequence([X|T1], [X|T2]) :- subsequence(T1, T2).
subsequence([X|T1], [_|T2]) :- subsequence([X|T1], T2).
*/
