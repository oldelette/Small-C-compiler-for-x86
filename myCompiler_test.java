import org.antlr.v4.runtime.*;
import java.util.*;

public class myCompiler_test {
    public static void main(String[] args) throws Exception
    {
        CharStream input = CharStreams.fromFileName(args[0]);
        myCompilerLexer lexer = new myCompilerLexer(input);
        CommonTokenStream tokens = new CommonTokenStream(lexer);

        myCompilerParser parser = new myCompilerParser(tokens);
        parser.program();
        /* Output data section */
        List<String> data_code = parser.getDataCode();

        System.out.println("/* Data section */");
        System.out.println("\t.section .data\n");
        for(int i=0; i < data_code.size(); i++)
            System.out.println(data_code.get(i));


        /* Output text section */
        List<String> text_code = parser.getTextCode();

        for(int i=0; i < text_code.size(); i++)
            System.out.println(text_code.get(i));
    }
}
