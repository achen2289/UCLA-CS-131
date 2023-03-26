let my_subset_test0 = subset [] [1; 2; 3]
let my_subset_test1 = subset [3; 1; 3] [1; 2; 3]
let my_subset_test2 = not (subset [1; 3 ; 7] [4; 1; 3])
let my_subset_test3 = subset [] []
let my_subset_test4 = subset [] [1]
let my_subset_test5 = subset [1] [1]
let my_subset_test6 = subset [1] [1; 2]
let my_subset_test7 = subset [1; 2] [1; 2; 3]
let my_subset_test8 = subset [1; 2] [1; 3; 2]
let my_subset_test9 = subset [1; 2; 3] [1; 4; 4; 3; 3; 2]
let my_subset_test10 = not (subset [1; 2; 3] [])
let my_subset_test11 = not (subset [1; 2; 3] [3; 2])
let my_subset_test12 = subset [1; 1; 1;] [1;]
let my_subset_test13 = subset ["a"; "b"] ["z"; "b"; "c"; "a"]
let my_subset_test14 = not (subset [["a"; "b"]] [["z"; "b"; "c"; "a"]])
let my_subset_test15 = subset [["a"; "b"]] [["a"; "b"]; ["z"; "b"; "c"; "a"]]
let my_subset_test16 = not (subset [["b"; "a"]] [["a"; "b"]; ["z"; "b"; "c"; "a"]])

let my_equal_sets_test0 = equal_sets [1; 3] [3; 1; 3]
let my_equal_sets_test1 = not (equal_sets [1; 3; 4] [3; 1; 3])
let my_equal_sets_test2 = equal_sets [] []
let my_equal_sets_test3 = not (equal_sets [] [1; 2;])
let my_equal_sets_test4 = not (equal_sets [2;] [1; 2;])
let my_equal_sets_test5 = equal_sets [1; 2;] [1; 2;]

let my_set_union_test0 = equal_sets (set_union [] [1; 2; 3]) [1; 2; 3]
let my_set_union_test1 = equal_sets (set_union [3; 1; 3] [1; 2; 3]) [1; 2; 3]
let my_set_union_test2 = equal_sets (set_union [] []) []
let my_set_union_test3 = equal_sets (set_union [1; 2] []) [2; 1]
let my_set_union_test4 = equal_sets (set_union [1; 2] []) [2; 1; 1]
let my_set_union_test5 = not (equal_sets (set_union [1; 2; 3] []) [2; 1; 1])
let my_set_union_test6 = not (equal_sets (set_union [1; 2; 3] [4]) [2; 1; 3])

let my_set_all_union_test0 =
  equal_sets (set_all_union []) []
let my_set_all_union_test1 =
  equal_sets (set_all_union [[3; 1; 3]; [4]; [1; 2; 3]]) [1; 2; 3; 4]
let my_set_all_union_test2 =
  equal_sets (set_all_union [[5; 2]; []; [5; 2]; [3; 5; 7]]) [2; 3; 5; 7]
let my_set_all_union_test3 =
  equal_sets (set_all_union [[]; [];]) []
let my_set_all_union_test4 =
  equal_sets (set_all_union [[1; 2; 2]; [3; 3; 3];]) [1; 2; 3]
let my_set_all_union_test5 =
  not (equal_sets (set_all_union [[1; 2; 2]; [3; 3; 3];]) [1; 2; 3; 4])

let my_computed_fixed_point_test0 =
  computed_fixed_point (=) (fun x -> x / 2 + 2) 8 = 4

let my_computed_periodic_point_test0 =
  computed_periodic_point (=) (fun x -> x * x - 2) 2 (-1) = -1

let my_whileseq_test0 =
  (whileseq ((+) 3) ((>) 0) 0) = []
let my_whileseq_test1 =
  (whileseq ((+) 3) ((>) 1) 0) = [0]
let my_whileseq_test2 =
  (whileseq ((-.) 5.5) ((<) 1.) 4.5) = [4.5]

type giant_nonterminals =
  | Conversation | Sentence | Grunt | Snore | Shout | Quiet

let giant_grammar =
  Conversation,
  [Snore, [T"ZZZ"];
   Quiet, [];
   Grunt, [T"khrgh"];
   Shout, [T"aooogah!"];
   Sentence, [N Quiet];
   Sentence, [N Grunt];
   Sentence, [N Shout];
   Conversation, [N Snore];
   Conversation, [N Sentence; T","; N Conversation]]

let my_filter_blind_alleys_test0 =
  filter_blind_alleys (Sentence, List.tl (List.tl (List.tl (snd giant_grammar)))) =
    (Sentence,
     [Shout, [T "aooogah!"]; Sentence, [N Shout]])


