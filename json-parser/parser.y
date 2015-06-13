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

/* the grammar is based on json.org */

%name parser

/*%token_type	{ void* }*/
%extra_argument { json_parser_t* pret }

%include {
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "parser.h"
#include "private/private.h"
}

%syntax_error {
	fprintf(stderr, "error starting @: %s", pret->token_start);
}

%type pair	{ json_pair_t }
%type memnbers	{ json_value_t* }
%type elements	{ json_value_t* }
%type object	{ json_value_t* }
%type array	{ json_value_t* }
%type value	{ json_value_t* }

%destructor pair	{ free($$.key); json_free($$.value); }
%destructor members	{ json_free($$); }
%destructor elements	{ json_free($$); }
%destructor array	{ json_free($$); }
%destructor object	{ json_free($$); }
%destructor value	{ json_free($$); }

%token_type	{ json_value_t* }

%token_destructor { json_free($$); }

%start_symbol root

/* a json file is either an object or an array */
root		::= object(B).			{ pret->root = B; }
root		::= array(B).			{ pret->root = B; }

/* literals */
pair(A)		::= JSON_TOK_STRING(B) JSON_TOK_COL value(C).	{ A = json_pair(B->value.string, C); free(B); }

members(A)	::= pair(B).				{ A = json_object(); json_add_pair(B, A); }
members(A)	::= members(B) JSON_TOK_COMMA pair(C).	{ A = json_add_pair(C, B); }

object(A)	::= JSON_TOK_LBRACK JSON_TOK_RBRACK.	{ A = json_object();	}
object(A)	::= JSON_TOK_LBRACK members(B) JSON_TOK_RBRACK.	{ A = B; }

array(A)	::= JSON_TOK_LSQB JSON_TOK_RSQB.	{ A = json_array();	}
array(A)	::= JSON_TOK_LSQB elements(B) JSON_TOK_RSQB.	{ A = B; }

elements(A)	::= value(B).				{ A = json_array(); json_add_element(B, A); }
elements(A)	::= elements(B) JSON_TOK_COMMA value(C).{ A = json_add_element(C, B); }

value(A)	::= JSON_TOK_STRING(B).			{ A = B; }
value(A)	::= JSON_TOK_NUMBER(B).			{ A = B; }
value(A)	::= JSON_TOK_BOOLEAN(B).		{ A = B; }
value(A)	::= JSON_TOK_NONE(B).			{ A = B; }
value(A)	::= object(B).				{ A = B; }
value(A)	::= array(B).				{ A = B; }

