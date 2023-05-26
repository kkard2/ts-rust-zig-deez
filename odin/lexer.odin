package lexer
// Usage: `odin test .` in this folder to exec tests
// Tests at end of file
Lexer :: struct {
	data:   []u8,
	offset: int,
	tokens: [dynamic]Token,
}

Token :: struct {
	offset: int,
	kind:   Token_Kind,
	text:   string,
}

Token_Kind :: enum {
	Illegal,
	Equal,
	Plus,
	Comma,
	Semicolon,
	Lparen,
	Rparen,
	LSquirly,
	RSquirly,
	Function,
	Let,
	Ident,
	Number,
	EOF,
}

init_lexer :: proc(data: string) -> Lexer {
	lexer := Lexer {
		data   = transmute([]u8)data,
        tokens = make([dynamic]Token),
	}
	return lexer
}

destroy_lexer::proc(l:^Lexer) {
    delete(l.tokens)
}

scan_tokens :: proc(l: ^Lexer) {
	for !is_at_end(l) {
		scan_token(l)
	}
	append(&l.tokens, Token{offset=l.offset,kind = .EOF})
}

scan_token :: proc(l: ^Lexer) {
	c := next(l)
    start:=l.offset-1
    // fmt.print(rune(c))
	switch c {
	case '(':
		append(&l.tokens, Token{start, .Lparen, "("})
	case ')':
		append(&l.tokens, Token{start, .Rparen, ")"})
	case '{':
		append(&l.tokens, Token{start, .LSquirly, "{"})
	case '}':
		append(&l.tokens, Token{start, .RSquirly, "}"})
	case ';':
		append(&l.tokens, Token{start, .Semicolon, ":"})
    case '=':
        append(&l.tokens, Token{start, .Equal, "="})
    case '+':
        append(&l.tokens, Token{start, .Plus, "+"})
	case ',':
		append(&l.tokens, Token{start, .Comma, ","})
	case ' ', '\n', '\r', '\t': // nop
	case:
		if is_digit(c) {
			number(l)
		} else if is_alpha(c) {
            if let(l) do break
            if fn(l) do break
            ident(l)
		} else {
			append(&l.tokens, Token{start, .Illegal,""})
		}
	}
}

is_at_end :: proc(l: ^Lexer) -> bool {
	return l.offset >= len(l.data)
}

next :: proc(l: ^Lexer) -> u8 #no_bounds_check {
	next: u8
	if l.offset < len(l.data) {
		next = l.data[l.offset]
		l.offset += 1
	}
	return next
}

peek :: proc(l: ^Lexer) -> u8 #no_bounds_check {
	if l.offset >= len(l.data) {
		return 0x0
	} else {
		return l.data[l.offset]
	}
}

is_digit :: proc(c: u8) -> bool {
	return c >= '0' && c <= '9'
}

is_alpha :: proc(c: u8) -> bool {
	return c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c == '_'
}

is_alpha_numeric :: proc(c: u8) -> bool {
	return is_alpha(c) || is_digit(c)
}

number :: proc(l: ^Lexer) {
	start := l.offset - 1
	for is_digit(peek(l)) do next(l)
	append(&l.tokens, Token{start, .Number, string(l.data[start:l.offset])})
}

let :: proc(l: ^Lexer) -> bool {
    start := l.offset - 1

    if l.offset + 2 >= len(l.data) || 
       l.data[l.offset] != 'e' || 
       l.data[l.offset + 1] != 't' || 
       is_alpha_numeric(l.data[l.offset + 2]) {
        return false
    }

    l.offset += 2 // skip 'e' and 't'
    append(&l.tokens, Token{start, .Let, string(l.data[start:l.offset])})

    return true
}

fn :: proc(l: ^Lexer) -> bool {
    start := l.offset - 1
    if l.offset + 1 >= len(l.data) || 
       l.data[l.offset] != 'n' || 
       is_alpha_numeric(l.data[l.offset + 1]) {
        return false
    }
    l.offset += 1 // skip 'n'
    append(&l.tokens, Token{start, .Function, string(l.data[start:l.offset])})
    return true
}

ident :: proc(l: ^Lexer) {
	start := l.offset - 1
	for is_alpha_numeric(peek(l)) do next(l)
	append(&l.tokens, Token{start, .Ident, string(l.data[start:l.offset])})
}

import "core:testing"
import "core:fmt"

tokens_are_equal :: proc(a: Token, b: Token) {
    // technically could comp struct literals, but this gives more info
    if a.offset != b.offset{
        fmt.println(a,b)
        panic("Token offset mismatch")
    }
    if a.kind != b.kind{
        fmt.println(a,b)
        panic("Token kind mismatch")
    }
    if a.text != b.text{
        fmt.println(a,b)
        panic("Token text mismatch")
    }
}

@(test)
test_lexer :: proc(t: ^testing.T) {
    data := "=+(){},;"
    lexer := init_lexer(data)
    scan_tokens(&lexer)

    expected_tokens := []Token{
        {0,  .Equal,    "="},
        {1,  .Plus,     "+"},
        {2,  .Lparen,   "("},
        {3,  .Rparen,   ")"},
        {4,  .LSquirly, "{"},
        {5,  .RSquirly, "}"},
        {6,  .Comma,    ","},
        {7,  .Semicolon,":"},
        {8,  .EOF,      ""},
    }

    for token,i in lexer.tokens {
        tokens_are_equal(lexer.tokens[i], expected_tokens[i])
    }
}

@(test)
test_lexer_full :: proc(t: ^testing.T) {
    data :=
        "let five = 5;\n" +
        "let ten = 10;\n" +
        "let add = fn(x, y) {\n" +
        "    x + y;\n" +
        "};\n" +
        "let result = add(five, ten);\n"
    lexer := init_lexer(data)
    defer destroy_lexer(&lexer)
    scan_tokens(&lexer)

    expected_tokens := []Token{
        {0,  .Let,      "let"},
        {4,  .Ident,    "five"},
        {9,  .Equal,    "="},
        {11, .Number,   "5"},
        {12, .Semicolon,":"},
        {14, .Let,      "let"},
        {18, .Ident,    "ten"},
        {22, .Equal,    "="},
        {24, .Number,   "10"},
        {26, .Semicolon,":"},
        {28, .Let,      "let"},
        {32, .Ident,    "add"},
        {36, .Equal,    "="},
        {38, .Function, "fn"},
        {40, .Lparen,   "("},
        {41, .Ident,    "x"},
        {42, .Comma,    ","},
        {44, .Ident,    "y"},
        {45, .Rparen,   ")"},
        {47, .LSquirly, "{"},
        {53, .Ident,    "x"},
        {55, .Plus,     "+"},
        {57, .Ident,    "y"},
        {58, .Semicolon,":"},
        {60, .RSquirly, "}"},
        {61, .Semicolon,":"},
        {63, .Let,      "let"},
        {67, .Ident,    "result"},
        {74, .Equal,    "="},
        {76, .Ident,    "add"},
        {79, .Lparen,   "("},
        {80, .Ident,    "five"},
        {84, .Comma,    ","},
        {86, .Ident,    "ten"},
        {89, .Rparen,   ")"},
        {90, .Semicolon,":"},
        {92, .EOF,      ""},
    }

    for token,i in lexer.tokens {
        tokens_are_equal(token, expected_tokens[i])
    }
}
