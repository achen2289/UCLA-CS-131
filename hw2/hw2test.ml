type simple_english_nonterminals =
  | Sentence | DP | VP | NP | D | Noun | V

let simple_english_grammar =
  (Sentence,
   function
     | Sentence ->
        [[N DP; N VP]]
     | DP ->
        [[N D; N NP];
         [N NP];
         [N D]]
     | VP ->
	      [[N V];
         [N V; N DP]]
     | NP ->
        [[N Noun]]
     | D ->
        [[T "The"];
         [T "A"];
         [T "This"]]
     | Noun ->
        [[T "Alex"]; 
         [T "Tristian"]; 
         [T "Mannie"]; 
         [T "Ricky"];
         [T "basketball"];
         [T "tetris"];
         [T "games"]]
     | V ->
        [[T "eats"];
         [T "beats"];
         [T "defeats"]])

let accept_empty = function
  | [] -> Some []
  | x -> None

let make_matcher_test =
  ((make_matcher simple_english_grammar accept_empty ["Alex"; "beats"; "Ricky"]) = Some [])

let test_frag = ["tetris"; "defeats"; "Ricky"]
let parse_tree = (make_parser simple_english_grammar test_frag)

let make_parser_test = match parse_tree with
  | Some tree -> ((parse_tree_leaves tree) = test_frag)
  | _ -> false

let make_parser_test_1 = 
  (parse_tree = (Some 
                  (Node (Sentence, [Node (DP, [Node (NP, [Node (Noun, [Leaf "tetris"])])]); 
                                    Node (VP, [Node (V, [Leaf "defeats"]);
                                               Node (DP, [Node (NP, [Node (Noun, [Leaf "Ricky"])])])])]
                  ))))
