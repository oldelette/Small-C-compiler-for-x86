grammar myCompiler;

@header {
 import java.util.*;
}

@members {
  boolean TRACEON = false;
  HashMap<String,Integer> symtab = new HashMap<String,Integer>();
  public enum TypeInfo {
    Int,
    Double,
    Float,
    Char,
    Void,
    Unknown,
    No_Exist,
    Error
  }
  
  /* attr_type:
     1 => integer,
     2 => float,
     3 => String constant,
     -1 => do not exist,
     -2 => error
  */
  
  List<String> DataCode = new ArrayList<String>();
  List<String> TextCode = new ArrayList<String>();
  
  public static register reg = new register(0, 10);
  String str = "";
  int print_count = 0;
  int arg_count = 0;
  int addr_reg_num;

  void prologue(String id)
  {
    TextCode.add("\n\n/* Text section */");
    TextCode.add("\t.section .text");
    TextCode.add("\t.global " + id);
    TextCode.add("\t.type " + id + ",%function");
    TextCode.add(id + ":");

	/* Follow x86 calling convention */
    /*
	TextCode.add("\t pushq \%rbp");
    TextCode.add("\t movq \%rsp,\%rbp");
    TextCode.add("\t pushq \%rbx"); //callee saved registers.
    TextCode.add("\t pushq \%r12"); //callee saved registers.
    TextCode.add("\t pushq \%r13"); //callee saved registers.
    TextCode.add("\t pushq \%r14"); //callee saved registers.
    TextCode.add("\t pushq \%r15"); //callee saved registers.
    TextCode.add("\t subq $8,\%rsp\n"); // aligned 16-byte boundary.
    */
	
	TextCode.add("\tmov ip, sp");
    TextCode.add("\tstmfd sp!, {r4-r10, fp, ip, lr, pc}");
    TextCode.add("\tsub fp, ip, #4");
  }

  void epilogue()
  {
    TextCode.add("\tldmea fp, {r4-r10, fp, sp, pc}");
	/*
	TextCode.add("\n\t addq $8,\%rsp");
    TextCode.add("\t popq \%r15");
    TextCode.add("\t popq \%r14");
    TextCode.add("\t popq \%r13");
    TextCode.add("\t popq \%r12");
    TextCode.add("\t popq \%rbx");
    TextCode.add("\t popq \%rbp");
	TextCode.add("\t ret");
	*/
  }

  public List<String> getDataCode()
  {
    return DataCode;
  }

  public List<String> getTextCode()
  {
    return TextCode;
  }
}

program
  : 'int' 'main' '(' ')' '{'
  {
    prologue("main");
  }
    statement+ '}'
  {
    epilogue();
  }
  ;

statement
  : expr ';'
  | 'printf' '('
    StringLiteral
    {
      arg_count = 1;
      DataCode.add(".PRINT" + print_count + ":");
      str = "";
      str = '"' + $StringLiteral.text.substring(1, $StringLiteral.text.length() - 1) + "\\000" + '"';
      DataCode.add("\t.ascii " + str);
      TextCode.add("\tldr " + "r0" + ",=.PRINT" + print_count);
    }
    (',' arg)+ ')' ';'
  {
    TextCode.add("\tbl printf");
    print_count++;
  }
  | type id ';'
  {
    if (TRACEON) System.out.println("declaration: " + $type.text + " " + $id.text);
    if (!symtab.containsKey($id.text)) {
      symtab.put($id.text, $type.attr_type);
      /* code generation */
  		DataCode.add("\t.type " + $id.text + ", %object");
  		DataCode.add($id.text + ":");
  		switch($type.attr_type) {
  		case 1: /* Type: integer, initial value is 0. */
  		  DataCode.add("\t.word 0");
  			break;
  		default:
  		}
    } else {
      System.out.println("Type Error: " + $id.start.getLine() + ": Redeclared identifier.");
    }
  }
  | ';'
  ;

expr returns [int attr_type, int reg_num]
  : sum
  {
    $attr_type = $sum.attr_type;
    $reg_num = $sum.reg_num;
  }
  | id '=' expr
  {
    if (TRACEON) System.out.println("expr: " + $id.text + " = " + $expr.text);
    if (symtab.containsKey($id.text)) {
      if (symtab.get($id.text) != $expr.attr_type) {
        System.out.println("Type Error: " + $id.start.getLine() + ": Type mismatch for = in an expression.");
      }
      $attr_type = symtab.get($id.text);
      /* code generation */
      $reg_num = reg.get(); /* get an register */
      TextCode.add("\tldr " + "r" + $reg_num + ",=" + $id.text);
      TextCode.add("\tstr " + "r" + $expr.reg_num + ", [" + "r" + $reg_num + "]");
    } else {
      System.out.println("Type Error: " + $id.start.getLine() + ": ‘" + $id.text + "’ undeclared");
    }
  }
  ;
sum returns [int attr_type, int reg_num]
  : a = term
  {
    $attr_type = $a.attr_type;
    $reg_num = $a.reg_num;
  }
  ('+' b = term
  {
    if ($a.attr_type != $b.attr_type) {
    System.out.println("Type Error: " + $a.start.getLine() + ": Type mismatch for the operator + in an expression.");
      $attr_type = -2;
    } else {
      /* code generation */
      TextCode.add("\tadd " + "r" + $a.reg_num + ", r" + $a.reg_num + ", r" + $b.reg_num);
    }
  }
  | '-' c = term
  {
    if ($a.attr_type != $c.attr_type) {
      System.out.println("Type Error: " + $a.start.getLine() + ": Type mismatch for the operator - in an expression.");
      $attr_type = -2;
    } else {
      /* code generation */
      TextCode.add("\tsub " + "r" + $a.reg_num + ", r" + $a.reg_num + ", r" + $c.reg_num);
    }
  }
  )*
  ;

arg
  : sum
  {
    TextCode.add("\tmov " + "r" + arg_count + ", r" + $sum.reg_num);
    arg_count += 1;
  }
  ;

type returns [int attr_type]
  : Int {$attr_type = 1;}
  ;

term returns [int attr_type, int reg_num]
  : id
  {
    if (symtab.containsKey($id.text)) {
      $attr_type = symtab.get($id.text);
      addr_reg_num = reg.get(); /* get an register */
      TextCode.add("\tldr " + "r" + addr_reg_num + ",=" + $id.text);
      $reg_num = reg.get();
      TextCode.add("\tldr " + "r" + $reg_num + ", [" + "r" + addr_reg_num + "]");
    } else {
      System.out.println("Type Error: " + $id.start.getLine() + ": ‘" + $id.text + "’ undeclared");
    }
  }
  | integer
  {
    if (TRACEON) System.out.println("type: int");
    $attr_type = 1;
    $reg_num = reg.get();  /* get an register */
    TextCode.add("\tmov " + "r" + $reg_num + ", #" + $integer.text);
  }
  ;

Int  : 'int';
Char : 'char';
Double : 'double';
Float : 'float';
Void : 'void';

If : 'if';
Else : 'else';
For : 'for';
While : 'while';

Add : '+';
Sub : '-';
Star : '*';
Div : '/';
COMMA	: (',');
PERIOD	: ('.');
SEMICOLON  : (';')+;
HASH	: ('#');
Assign : '=';
Return : 'return';

id : STRING;
integer : INT;

STRING: [a-z]+;
INT : [0-9]+;
Whitespace : [ \t]+ -> skip;
Newline : ('\r' '\n'? | '\n' ) -> skip;
BlockComment : '/*' .*? '*/' -> skip;
LineComment : '//' ~[\r\n]* -> skip;
