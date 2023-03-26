(* Returns whether or not a is a subset of b. *)
let rec subset a b = match a with
    | [] -> true
    | _ -> if (List.mem (List.hd a) b) then
                subset (List.tl a) b
           else
                false

(* Returns whether or not a and b are equivalent sets. *)
let equal_sets a b = (subset a b) && (subset b a)

(* Returns the union of a and b. Duplicates are allowed since sets are represented by lists. *)
let rec set_union a b = match a with
     | [] -> b
     | _ -> set_union (List.tl a) ((List.hd a)::b)

(* Returns the union of all the sets within a, where a is a set of sets. *)
let rec set_all_union a = match a with
     | [] -> []
     | _ -> set_union (List.hd a) (set_all_union (List.tl a))

(* This function cannot be written in OCaml. If a set s, of type 'a list, is a member of itself, then 
s would also need to contain elemtns of type 'a list, making it contain both 'a and 'a list types. 
However, this is not possible in OCaml because lists must be homogenous. *)

(* Compute fixed point, where f x = x. *)
let rec computed_fixed_point eq f x = 
     if (eq x (f x)) then
          x
     else
          computed_fixed_point eq f (f x)

(* Computes the periodic point of function f with period p with respect to x. Uses
helper function to calculate the value of f (f...(f x)) where f is called p times. *)
let rec periodic_func f p x = match p with
     | 1 -> (f x)
     | _ -> (periodic_func f (p-1) (f x))

let rec computed_periodic_point eq f p x = match p with
     | 0 -> x
     | 1 -> computed_fixed_point eq f x
     | _  -> if (eq (periodic_func f p x) x) then
               x
             else
               computed_periodic_point eq f p (f x)

(* Returns longest list [x; s x; s (s x); ...] such that p e is true for every element e in list.
Assume p eventually returns false. *)
let rec whileseq s p x = 
     if not (p x) then
          []
     else
          x::(whileseq s p (s x))

(* Filter out blind-alley rules. *)

(* Symbol def. *)
type ('nonterminal, 'terminal) symbol =
  | N of 'nonterminal
  | T of 'terminal

(* Determine if a symbol is terminal or eventually evaluates to a terminal string. *)
let is_symbol_terminal s term_syms = match s with
     | T _ -> true
     | N s -> (List.mem s term_syms)

(* Determine if the rhs of a rule will terminate. *)
let rec is_rhs_terminable rhs term_syms = match rhs with
     | [] -> true
     | h::t -> if (is_symbol_terminal h term_syms) then 
                    (is_rhs_terminable t term_syms)
               else
                    false

(* Take in grammar rules and terminal symbols and add all terminable symbols to term_syms. *)
let rec construct_grammar_helper rules term_syms = match rules with
     | [] -> term_syms
     | (a, rhs)::t -> if (is_rhs_terminable rhs term_syms) && not (List.mem a term_syms) then
                         construct_grammar_helper t (a::term_syms)
                      else
                         construct_grammar_helper t term_syms

(* Take in rules and terminal symbols and return grammar. *)
let construct_grammar (rules, term_syms) =
     rules, (construct_grammar_helper rules term_syms)

(* Determine if two 2-tuple 2nd values are equal. *)
let are_snd_equal_sets (a1, b1) (a2, b2) = equal_sets b1 b2

(* Filter out blind-alley rule helper. *)
let rec filter_helper rules term_syms new_rules = match rules with
     | [] -> new_rules
     | (a, rhs)::t -> if (is_rhs_terminable rhs term_syms) then
                         (filter_helper t term_syms (new_rules@[(a, rhs)]))
                      else
                         (filter_helper t term_syms new_rules)

(* Filter out blind-alley rules. *)
let filter_blind_alleys g = 
     let start = (fst g) and rules = (snd g) in
     start, (filter_helper rules (snd (computed_fixed_point are_snd_equal_sets construct_grammar ((snd g), []))) [])