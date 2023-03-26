type ('nonterminal, 'terminal) symbol =
  | N of 'nonterminal
  | T of 'terminal

(* Take in original grammar rules and consolidate all RHS rules for specified LHS nonterminal. *)
let convert_grammar_rules gram1_rules nonterminal = 
  let consolidated_rules = List.split (List.filter (fun rule -> (fst rule) = nonterminal) gram1_rules) in
  (snd consolidated_rules)

(* Convert grammar rule format to new format, which is (start symbol, function that
pattern matches a nonterminal to a list of its rules). *)
let convert_grammar gram1 = match gram1 with
    | (start, gram1_rules) -> (start, (convert_grammar_rules gram1_rules))


type ('nonterminal, 'terminal) parse_tree =
  | Node of 'nonterminal * ('nonterminal, 'terminal) parse_tree list
  | Leaf of 'terminal

let rec parse_tree_leaves_helper leaves node_list = match node_list with
  | [] -> leaves
  | head::tail -> match head with 
                    | Leaf terminal -> parse_tree_leaves_helper (leaves@[terminal]) tail
                    | Node (nonterminal, children) -> parse_tree_leaves_helper leaves (children@tail)

(* Do a traversal of parse tree and return list of leaves encountered from left to right. *)
let parse_tree_leaves tree = parse_tree_leaves_helper [] [tree]


(* Try all curr_rules in order and attempt to match frag with any of the rules.
Parse rules and evaluate each individually with helper function. *)
let rec match_grammar_rules all_rules curr_rules accept frag = match curr_rules with
  | [] -> None
  | head::tail -> let curr_rule_res = (match_current_grammar_rule all_rules head accept frag) in
                  match curr_rule_res with
                    | None -> (match_grammar_rules all_rules tail accept frag)
                    | _ -> curr_rule_res

(* Attempt to match a grammar rule to a frag. If curr_rule is empty, we can 
accept frag because no rule opposes it. Otherwise, try to match frag with the
rule. If rule head is terminal, check rest of rule and rest of frag. If rule
head is nonterminal, use new acceptor that checks for match in rest of rule. *)
and match_current_grammar_rule all_rules curr_rule accept frag = match curr_rule with
  | [] -> accept frag
  | rule_head::rule_tail -> match frag with
    | [] -> None
    | frag_head::frag_tail -> match rule_head with
      | T terminal -> if terminal = frag_head then
                        match_current_grammar_rule all_rules rule_tail accept frag_tail
                      else
                        None
      | N nonterminal -> let new_acceptor = (match_current_grammar_rule all_rules rule_tail accept) in
                          match_grammar_rules all_rules (all_rules nonterminal) new_acceptor frag

(* Return grammar matcher result with accept function and a frag. *)
let make_matcher gram = match gram with
  | (start, gram_rules) -> fun accept frag -> match_grammar_rules gram_rules (gram_rules start) accept frag


(* New acceptor for make_parser() that matches any completely processed fragment. *)
let accept_complete_parse frag tree = match frag with
  | [] -> Some tree
  | _ -> None

let rec match_grammar_rules_modified all_rules start_symbol curr_rules accept frag tree = match curr_rules with
  | [] -> None
  | head::tail -> let curr_rule_res = (match_current_grammar_rule_modified all_rules start_symbol head accept frag tree) in
                  match curr_rule_res with
                    | None -> (match_grammar_rules_modified all_rules start_symbol tail accept frag tree)
                    | _ -> curr_rule_res

and match_current_grammar_rule_modified all_rules start_symbol curr_rule accept frag tree = match curr_rule with
  | [] -> accept frag (Node(start_symbol, tree))
  | rule_head::rule_tail -> match frag with
    | [] -> None
    | frag_head::frag_tail -> match rule_head with
      | T terminal -> if terminal = frag_head then 
                        let curr_leaf = (Leaf terminal) in
                        match_current_grammar_rule_modified all_rules start_symbol rule_tail accept frag_tail (tree@[curr_leaf])
                      else
                        None
      | N nonterminal -> let new_acceptor new_frag new_tree = (match_current_grammar_rule_modified all_rules start_symbol rule_tail accept new_frag (tree@[new_tree])) in
                          match_grammar_rules_modified all_rules nonterminal (all_rules nonterminal) new_acceptor frag []

(* Modified version of make_matcher() that has additional parameters start_symbol
and "tree" which represent the current start_symbol node and tree rooted at that node. *)
let make_matcher_modified gram = match gram with
  | (start_symbol, gram_rules) -> fun accept frag -> match_grammar_rules_modified gram_rules start_symbol (gram_rules start_symbol) accept frag []

(* Uses a modified version of make_matcher(). *)
let make_parser gram = fun frag -> make_matcher_modified gram accept_complete_parse frag
