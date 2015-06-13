/*
** json-parser Copyright 2015(c) Wael El Oraiby. All Rights Reserved
**
** This library is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** Under Section 7 of GPL version 3, you are granted additional
** permissions described in the GCC Runtime Library Exception, version
** 3.1, as published by the Free Software Foundation.
**
** You should have received a copy of the GNU General Public License and
** a copy of the GCC Runtime Library Exception along with this program;
** see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see
** <http://www.gnu.org/licenses/>.
**
*/
/*
 grammar parser: using Lemon, not YACC nor BISON
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "private/private.h"
#include "parser.h"

extern void*	parser_alloc(void *(*mallocProc)(size_t));
extern void	parser_free(void *p, void (*freeProc)(void*));
extern void	parser_advance(void *yyp, int yymajor, json_value_t* yyminor, json_parser_t* s);


#define ADVANCE(A, T)	parser_.token_start	= ts; \
			parser_.token_end	= te; \
			parser_.token_line	= line; \
			copy_token(ts, te, tmp); \
			json_value_t* tmpc = token_to_##A(tmp); \
			parser_advance(yyparser, T, tmpc, &parser_)

#define ADVANCE_TOKEN(A)	parser_advance(yyparser, A, NULL, &parser_)

#define PUSH_TE()	const char* tmp_te = te
#define POP_TE()	te	= tmp_te
#define PUSH_TS()	const char* tmp_ts = ts
#define POP_TS()	ts	= tmp_ts

/* EOF char used to flush out that last token. This should be a whitespace
 * token. */

#define LAST_CHAR 0


%%{
	machine scanner;
	write data nofinal;

	# Floating literals.
	fract_const	= ([0] | digit+) '.' digit+ | digit+ '.';
	exponent	= [eE] [+\-]? digit+;

	action inc_line { ++line; }

	c_comment	:= (any | '\n'@inc_line)* :>> '*/' @{ fgoto main; };

	main := |*
		'true'						{ ADVANCE( boolean, JSON_TOK_BOOLEAN );};
		'false'						{ ADVANCE( boolean, JSON_TOK_BOOLEAN );};
		'null'						{ ADVANCE( none, JSON_TOK_NONE ); };

		# string.
		( '"' ( [^"\\\n] | /\\./ )* '"' )		{
									PUSH_TE();
									PUSH_TS();
									++ts; --te;
									ADVANCE(string, JSON_TOK_STRING);
									POP_TS();
									POP_TE();
								};


		# Integer decimal. Leading part buffered by float.
		( [+\-]? ( '0' | [1-9] [0-9]* ) )		{ ADVANCE( number, JSON_TOK_NUMBER ); };

		( [+\-]? ( '0' | [1-9] [0-9]* ) [a-zA-Z_]+ )	{
									fprintf(stderr, "Error: invalid number:\n    ");

									for( i = ts; i < te; ++i ) {
										fprintf(stderr, "%c", *i);
									}
									fprintf(stderr, "\n");
									cs	= scanner_error;
								};

		# Floating literals.
		( [+\-]? fract_const exponent? | [+\-]? digit+ exponent ) 	{ ADVANCE( number, JSON_TOK_NUMBER );};

		# Only buffer the second item, first buffered by symbol. */
		'{'						{ ADVANCE_TOKEN( JSON_TOK_LBRACK );};
		'}'						{ ADVANCE_TOKEN( JSON_TOK_RBRACK );};
		'['						{ ADVANCE_TOKEN( JSON_TOK_LSQB );};
		']'						{ ADVANCE_TOKEN( JSON_TOK_RSQB );};
		':'						{ ADVANCE_TOKEN( JSON_TOK_COL );};
		','						{ ADVANCE_TOKEN( JSON_TOK_COMMA );};

		'\n'						{ ++line; };

		# Single char symbols.
		( punct - [_"'] )				{ printf("unexpected character %c\n", *ts); };

		# Comments and whitespace.
		'/*'						{ fgoto c_comment; };
		'//' [^\n]* '\n'@inc_line;
		( any - 33..126 )+;
	*|;
}%%

static int
copy_token(const char* ts, const char *te, char* dst) {
	int	index	= 0;
	while( ts < te ) {
		dst[index++]	= *ts;
		++ts;
	}
	dst[index] = '\0';
	return index;
}

static json_value_t*
token_to_string(const char* b) {
	size_t	len	= strlen(b);
	char*	str = (char*)malloc(len + 1);
	memcpy(str, b, len + 1);
	return json_string(str);
}

static json_value_t*
token_to_boolean(const char* b) {
	if( !strcmp(b, "true") ) {
		return json_boolean(true);
	} else {
		return json_boolean(false);
	}
}

static json_value_t*
token_to_number(const char* r) {
	double	v	= 0.0;
	sscanf(r, "%lf", &v);
	/* TODO: check limit */
	return json_number(v);
}

static json_value_t*
token_to_none(const char* str) {
	return json_none();
}


json_value_t*
json_parse(const char* str)
{
	json_parser_t		parser_;

	void*		yyparser;
	size_t		line	= 1;
	const char*	ts	= str;
	const char*	te	= str;
	const char*	i	= NULL;

	const char*	p	= str;
	const char*	pe	= p + strlen(str) + 1;
	const char*	eof	= NULL;

	int		act	= 0;
	int		cs	= 0;
	char		tmp[4096];

	parser_.root	= NULL;

	yyparser	= parser_alloc(malloc);

	memset(tmp, 0, sizeof(tmp));

	%% write init;

	%% write exec;

	/* Check if we failed. */
	if ( cs == scanner_error ) {
		/* Machine failed before finding a token. */
		printf("PARSE ERROR\n");
		return parser_.root;	/* failed! */
	}

	parser_advance(yyparser, 0, NULL, &parser_);

	parser_free(yyparser, free);
	return parser_.root;
}

