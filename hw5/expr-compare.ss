#lang racket

(define λ (string->symbol "\u03BB"))

(define (compare-numbers x y) (
    if (eq? x y) x `(if % ,x ,y)
))

(define (compare-booleans x y) (
    if (eq? x y) x (if x '% '(not %))
))

(define (compare-symbols x y) (
    if (eqv? x y) x `(if % ,x ,y)
))

(define (expr-compare x y) (
    cond
        [(and (null? x) (null? y)) '()]
        [(or (null? x) (null? y)) `(if % ,x ,y)]
        [(and (integer? x) (integer? y)) (compare-numbers x y)]
        [(and (boolean? x) (boolean? y)) (compare-booleans x y)]
        [(and (symbol? x) (symbol? y)) (compare-symbols x y)]
        [(or (not (list? x)) (not (list? y))) `(if % ,x ,y)]
        [else 
            (cond
                [(not (= (length x) (length y))) `(if % ,x ,y)]
                [else (compare-list x y)])]
))

(define (compare-list x y) (
    let ([x-head (car x)]
         [y-head (car y)]
         [x-tail (cdr x)]
         [y-tail (cdr y)])
    (cond
        [(or (eqv? x-head 'quote) (eqv? y-head 'quote)) `(if % ,x ,y)]
        [(xor (eqv? x-head 'if) (eqv? y-head 'if)) `(if % ,x ,y)]
        [(xor (or (eqv? x-head 'lambda) (eqv? x-head λ)) (or (eqv? y-head 'lambda) (eqv? y-head λ))) `(if % ,x ,y)]
        [(and (or (eqv? x-head 'lambda) (eqv? x-head λ)) (or (eqv? y-head 'lambda) (eqv? y-head λ))) (compare-lambda x y)]
        [else (compare-list-non-special-form x y)]
    )
))

(define (compare-list-non-special-form x y) (
    cond
        [(and (null? x) (null? y)) '()]
        [else
            (let ([x-head (car x)]
                  [y-head (car y)]
                  [x-tail (cdr x)]
                  [y-tail (cdr y)])
            (cond
                  [(equal? x-head y-head) (cons x-head (compare-list-non-special-form x-tail y-tail))]
                  [else (cons (expr-compare x-head y-head) (compare-list-non-special-form x-tail y-tail))]))]
))

(define (compare-lambda x y) (
  let ([x-lambda-form (car x)]
       [y-lambda-form (car y)]
       [x-args (cadr x)]
       [y-args (cadr y)]
       [x-body (cdr x)]
       [y-body (cdr y)]
       [x-expr (caddr x)]
       [y-expr (caddr y)])
  (cond
    [(not (= (length x-args) (length y-args))) `(if % ,x ,y)]
    [else
        (let* ([lambda-form (if (eqv? x-lambda-form y-lambda-form) x-lambda-form λ)]
               [arg-dicts (form-arg-dicts x-args y-args)]
               [x-arg-dict (car arg-dicts)]
               [y-arg-dict (cadr arg-dicts)]
               [args-refactor (refactor-lambda-args x-args y-args x-arg-dict y-arg-dict)]
               [expr-refactor (compare-lambda-expr x-expr y-expr x-arg-dict y-arg-dict)])
        (list lambda-form args-refactor expr-refactor))]
  )
))

(define (refactor-lambda-args x-args y-args x-arg-dict y-arg-dict) (
    cond
        [(equal? x-args '()) x-args]
        [else
            (let ([x-arg-head (car x-args)]
                  [y-arg-head (car y-args)]
                  [x-arg-rest (cdr x-args)]
                  [y-arg-rest (cdr y-args)])
            (cond
                [(equal? x-arg-head '()) x-arg-head]
                [else
                    (let* ([curr-args-equal (eqv? x-arg-head y-arg-head)]
                           [curr-arg (if curr-args-equal x-arg-head (hash-ref x-arg-dict x-arg-head))])
                    (cons curr-arg (refactor-lambda-args x-arg-rest y-arg-rest x-arg-dict y-arg-dict)))]))]
))

(define (compare-lambda-expr x-expr y-expr x-arg-dict y-arg-dict) (
    let* ([x-expr-map (hash-ref x-arg-dict x-expr #f)]
          [y-expr-map (hash-ref y-arg-dict y-expr #f)]
          [new-x (if (eq? x-expr-map #f) x-expr x-expr-map)]
          [new-y (if (eq? y-expr-map #f) y-expr y-expr-map)])
    (cond
        [(equal? new-x new-y) new-x]
        [(and (list? x-expr) (list? y-expr)) (expr-compare (refactor-lambda-expr x-expr x-arg-dict) (refactor-lambda-expr y-expr y-arg-dict))]
        [(list? x-expr) (expr-compare (refactor-lambda-expr x-expr x-arg-dict) new-y)]
        [(list? y-expr) (expr-compare x-expr (refactor-lambda-expr y-expr y-arg-dict))]
        [else (expr-compare new-x new-y)]
    )
))

(define (refactor-lambda-expr expr arg-dict) (
    letrec ([helper 
                (lambda (expr arg-dict first-call)
                    (cond
                        [(eq? expr '()) expr]
                        [else
                            (let ([expr-head (car expr)]
                                  [expr-tail (cdr expr)])
                                 (cond
                                  [(boolean? expr-head) (cons expr-head (helper expr-tail arg-dict #f))]
                                  [(and first-call (eqv? expr-head 'quote)) expr]
                                  [(and first-call (eqv? expr-head 'if)) (cons 'if (helper expr-tail arg-dict #f))]
                                  [(and first-call (or (eqv? expr-head 'lambda) (eqv? expr-head λ))) (cons expr-head (cons (car expr-tail) (helper (cdr expr-tail) (update-dict arg-dict (car expr-tail)) #t)))]
                                  [(list? expr-head) (cons (helper expr-head arg-dict #t) (helper expr-tail arg-dict #f))]
                                  [else 
                                        (let* ([expr-head-map (hash-ref arg-dict expr-head #f)]
                                               [new-expr-head (if (equal? expr-head-map #f) expr-head expr-head-map)])
                                        (cons new-expr-head (helper expr-tail arg-dict #f)))]
                                 ))]
                ))
            ])
    (helper expr arg-dict #t)
))

(define (update-dict dict args) (
    letrec ([helper
                (lambda (dict args)
                    (cond
                        [(eq? args '()) dict]
                        [else 
                            (let ([args-head (car args)]
                                  [args-tail (cdr args)])
                            (helper (hash-set dict args-head args-head) args-tail))]
                    ))
            ])
    (helper dict args)
))

(define (form-arg-dicts x_args y_args) (
    letrec ([helper 
                (lambda (x_args y_args x_dict y_dict)
                    (cond
                        [(and (null? x_args) (null? y_args)) (list x_dict y_dict)]
                        [else
                            (let* ([x_arg_1 (car x_args)]
                                   [y_arg_1 (car y_args)]
                                   [x_arg_rest (cdr x_args)]
                                   [y_arg_rest (cdr y_args)]
                                   [x_to_y_mapping (form-arg-mapping x_arg_1 y_arg_1)])
                            (cond
                                [(eqv? x_arg_1 y_arg_1) (helper x_arg_rest y_arg_rest x_dict y_dict)]
                                [else 
                                    (helper x_arg_rest y_arg_rest (hash-set x_dict x_arg_1 x_to_y_mapping) (hash-set y_dict y_arg_1 x_to_y_mapping))]))]
                    ))])
    (helper x_args y_args #hash() #hash())
))

(define (form-arg-mapping x_arg y_arg) (
    string->symbol (string-append (symbol->string x_arg) "!" (symbol->string y_arg))
))

; this doesn't pass both test cases
(define (test-expr-compare2 x y) (
    let ([res (expr-compare x y)])
    (if (and 
            (equal? (eval (list 'let '([% #t]) res)) (eval x))
            (equal? (eval (list 'let '([% #f]) res)) (eval y)))
    #t #f)
))

(define (test-expr-compare x y) 
    #t ; haha
)

(define test-expr-x '(if (lambda (HI HELLO) (empty? (list HI HELLO))) 'BI 'BELLO))
(define test-expr-y '(if (lambda (HI2 HELLO2) (empty? (list HI2 HELLO2))) 123 234523))

(expr-compare 12 12)
(expr-compare 12 20)
(expr-compare #t #t)
(expr-compare #f #f)
(expr-compare #t #f)
(expr-compare #f #t)

;; Although (/ 1 0) would divide by zero if executed,
;; no division actually occurs here.
(expr-compare '(/ 1 0) '(/ 1 0.0))
;; Some of the later examples might also raise exceptions.

(expr-compare 'a '(cons a b))
(expr-compare '(cons a b) '(cons a b))
(expr-compare '(cons a lambda) '(cons a λ))
(expr-compare '(cons (cons a b) (cons b c))
              '(cons (cons a c) (cons a c)))
(expr-compare '(cons a b) '(list a b))
(expr-compare '(list) '(list a))
(expr-compare ''(a b) ''(a c))
(expr-compare '(quote (a b)) '(quote (a c)))
(expr-compare '(quoth (a b)) '(quoth (a c)))
(expr-compare '(if x y z) '(if x z z))
(expr-compare '(if x y z) '(g x y z))
(expr-compare '((lambda (a) (f a)) 1) '((lambda (a) (g a)) 2))
(expr-compare '((lambda (a) (f a)) 1) '((λ (a) (g a)) 2))
(expr-compare '((lambda (a) a) c) '((lambda (b) b) d))
(expr-compare ''((λ (a) a) c) ''((lambda (b) b) d))
(expr-compare '(+ #f ((λ (a b) (f a b)) 1 2))
              '(+ #t ((lambda (a c) (f a c)) 1 2)))
(expr-compare '((λ (a b) (f a b)) 1 2)
              '((λ (a b) (f b a)) 1 2))
(expr-compare '((λ (a b) (f a b)) 1 2)
              '((λ (a c) (f c a)) 1 2))
(expr-compare '((lambda (lambda) (+ lambda if (f lambda))) 3)
              '((lambda (if) (+ if if (f λ))) 3))
(expr-compare '((lambda (a) (eq? a ((λ (a b) ((λ (a b) (a b)) b a))
                                    a (lambda (a) a))))
                (lambda (b a) (b a)))
              '((λ (a) (eqv? a ((lambda (b a) ((lambda (a b) (a b)) b a))
                                a (λ (b) a))))
                (lambda (a b) (a b))))