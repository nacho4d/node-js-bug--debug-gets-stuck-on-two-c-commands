use v5;

package Perlito5::Java::Runtime;

sub emit_java_extends {
    my ($class, $java_classes) = @_;
    # extends the imported Java classes
    # that were declared with
    #
    #   package My::X { extends => "My::Object" }
    #

    # 'extends' => 'My::Object',
    # 'extends_java_type' => 'Object',
    # 'java_native_to_perl' => 'pMyX',
    # 'java_type' => 'MyX',
    # 'perl_package' => 'My::X',
    # 'perl_to_java' => 'to_MyX',
    # 'Java::inline' => " // ... Java code ... \n",
    # 'methods' => [
    #     instance_meth => {
    #         decl => [ "public" ],
    #         return => "Int",
    #         args => [ "Int" ],     # this/$self is added to the Perl method arguments
    #         code => "MyClass::instance_meth",
    #     },
    #     class_meth => {
    #         decl => [ "public", "static" ],
    #         return => "Int",
    #         args => [ "Int" ],     # class name is added to the Perl method arguments
    #         code => "MyClass::class_meth",
    #     },
    #
    # TODO: constructors, variables
    #
    #     MyX => {
    #         decl => [ "public" ],
    #         return => undef,       # a constructor doesn't return anything
    #         args => [],
    #         Java::inline => '{ super(123) }',
    #     },
    # ],
    # 'variables' => [
    #     myName => {
    #         decl => [ "public" ],
    #         type => "String",
    #     },
    # ],

    my @out;
    push @out, "class $class->{java_type} extends $class->{extends_java_type} {";
    push @out, $class->{'Java::inline'} if $class->{'Java::inline'};
    while ( @{ $class->{variables} } ) {
        my $method = shift @{ $class->{variables} };
        my $data   = shift @{ $class->{variables} };
        # TODO
        #
    }
    while ( @{ $class->{methods} } ) {
        my $method = shift @{ $class->{methods} };
        my $data   = shift @{ $class->{methods} };
        my $decl   = $data->{decl};
        my $code   = $data->{code}   or die "Java extends: missing 'code' argument in method '$method'";
        my $return = $data->{return} or die "Java extends: missing 'return' argument in method '$method'";
        my @args;
        my $var = 0;
        for my $arg ( @{ $data->{args} } ) {
            my $type = $java_classes->{$arg};
            push @args, "$type->{java_type} param$var";
            $var++;
        }
        my @java_decl = @$decl;
        my $return_type = $return;
        if ( $return ne "void" ) {
            my $type = $java_classes->{$return};
            $return_type = $type->{java_type};
        }
        push @out, "    @java_decl $return_type $method(" . join(", ", @args) . ") {";

        @args = ();
        if ( grep { $_ eq "static" } @$decl ) {
            # class method
            push @args, "new PlString(\"$class->{perl_package}\")";
        }
        else {
            # instance method
            push @args, "new $class->{java_native_to_perl}(this)";
        }
        $var = 0;
        for my $arg ( @{ $data->{args} } ) {
            my $type = $java_classes->{$arg};
            push @args, "new $type->{java_native_to_perl}(param$var)";
            $var++;
        }
        push @out, "        PlObject[] res = Main.apply(\"$code\", " . join(", ", @args) . ");";

        if ( $return eq "void" ) {
            # void method
            push @out, "        return;";
        }
        else {
            my $type = $java_classes->{$return}
              or die "Java class '$return' is not imported";
            push @out, "        return res[0].$type->{perl_to_java}();";
        }

        # public Int instance_meth(Int param1) {
        #     PlInt p1 = new PlInt(param1);
        #     PlObject[] res = Main.apply("MyClass::instance_meth", this, p1);
        #     return res[0].to_Int();
        # }
        # public Int class_meth(Int param1) {
        #     PlObject[] res = Main.apply("MyClass::class_meth", param1);
        #     return res[0].to_Int();
        # }

        push @out, "    }";
    }
    push @out, "}\n";
    return join("\n", @out);
}

sub emit_java {
    my ($self, %args) = @_;
    my %java_classes = %{ $args{java_classes} // {} };

    my %number_binop = (
        add    => { op => '+',  returns => 'PlInt',  num_returns => 'PlDouble'}, 
        sub    => { op => '-',  returns => 'PlInt',  num_returns => 'PlDouble'},
        mul    => { op => '*',  returns => 'PlInt',  num_returns => 'PlDouble'},
        div    => { op => '/',  returns => 'PlDouble',  num_returns => 'PlDouble'},
        num_eq => { op => '==', returns => 'PlBool', num_returns => 'PlBool' },
        num_ne => { op => '!=', returns => 'PlBool', num_returns => 'PlBool' },
        num_lt => { op => '<',  returns => 'PlBool', num_returns => 'PlBool' },
        num_le => { op => '<=', returns => 'PlBool', num_returns => 'PlBool' },
        num_gt => { op => '>',  returns => 'PlBool', num_returns => 'PlBool' },
        num_ge => { op => '>=', returns => 'PlBool', num_returns => 'PlBool' },
    );
    my %string_binop = (
        str_eq => { op => '== 0', returns => 'PlBool' },
        str_ne => { op => '!= 0', returns => 'PlBool' },
        str_lt => { op => '< 0',  returns => 'PlBool' },
        str_le => { op => '<= 0', returns => 'PlBool' },
        str_gt => { op => '> 0',  returns => 'PlBool' },
        str_ge => { op => '>= 0', returns => 'PlBool' },
    );

    my %native_to_perl = (
        int     => 'PlInt',
        double  => 'PlDouble',
        boolean => 'PlBool',
        String  => 'PlString',
    );
    for (values %java_classes) {
        $native_to_perl{$_->{java_type}} = $_->{java_native_to_perl};
    }

    return <<'EOT'
// start Perl-Java runtime
// this is generated code - see: lib/Perlito5/Java/Runtime.pm

import java.lang.Math;
import java.lang.System;
import java.util.*;
import java.io.*;
import java.util.regex.Pattern;
import java.util.regex.Matcher;
import java.util.concurrent.TimeUnit;
EOT
        # import the Java classes
        # that were declared with
        #
        #   package My::Java { import => "org.My.Java", ... }
        #
    . join('', ( map {
                    my $class = $_;
                    $class->{import} ? "import $class->{import};\n" : ()
            }
            values %java_classes
      ))
        # extends the imported Java classes
        # that were declared with
        #
        #   package My::Java { extends => "My::Java", ... }
        #
    . join('', ( map {
                    my $class = $_;
                    $class->{extends} ? emit_java_extends($class, \%java_classes) : ()
            }
            values %java_classes
      ))
        # Perl-Java exceptions
    . <<'EOT'
class PlControlException extends RuntimeException {
}
class PlNextException    extends PlControlException {
    public int label_id;

    public PlNextException(int i) {
        this.label_id = i;
    }
}
class PlLastException    extends PlControlException {
    public int label_id;

    public PlLastException(int i) {
        this.label_id = i;
    }
}
class PlRedoException    extends PlControlException {
    public int label_id;

    public PlRedoException(int i) {
        this.label_id = i;
    }
}
class PlReturnException  extends PlControlException {
    public PlObject ret;

    public PlReturnException(PlObject ret) {
        this.ret = ret;
    }
}
class PlDieException  extends PlControlException {
    public PlObject ret;

    public PlDieException(PlObject ret) {
        this.ret = ret;
    }
    public String getMessage() {
        return this.ret.toString();
    }
}
class PlCx {
    public static final int     VOID   = 0;
    public static final int     SCALAR = 1;
    public static final int     LIST   = 2;
    public static final PlUndef  UNDEF  = new PlUndef();
    public static final PlBool   TRUE   = new PlBool(true);
    public static final PlBool   FALSE  = new PlBool(false);
    public static final PlString STDOUT = new PlString("STDOUT");
    public static final PlString STDERR = new PlString("STDERR");
    public static final PlString STDIN  = new PlString("STDIN");
    public static final PlString DIED   = new PlString("Died");
    public static final PlString EMPTY  = new PlString("");
    public static final String  ARGV   = "main::List_ARGV";
    public static final String  ENV    = "main::Hash_ENV";
    public static final PlNextException NEXT = new PlNextException(0);
    public static final PlLastException LAST = new PlLastException(0);

EOT
    . "    " . join("\n    ",
        map { "public static final PlInt " . ($_ < 0 ? "MIN" : "INT") . abs($_) . " = new PlInt($_);" }
            (-2 .. 2) ) . "\n"
    . "    " . join("\n    ", @{ $args{java_constants} // [] } ) . "\n"
    . <<'EOT'
}
class PlCORE {
    public static final PlObject print(int want, PlObject filehandle, PlArray List__) {
        // TODO - write to filehandle
        for (int i = 0; i < List__.to_int(); i++) {
            System.out.print(List__.aget(i).toString());
        }
        return PlCx.INT1;
    }
    public static final PlObject say(int want, PlObject filehandle, PlArray List__) {
        // TODO - write to filehandle
        for (int i = 0; i < List__.to_int(); i++) {
            System.out.print(List__.aget(i).toString());
        }
        System.out.println("");
        return PlCx.INT1;
    }
    public static final PlObject say(String s) {
        // say() shortcut
        return PlCORE.say(PlCx.VOID, PlCx.STDOUT, new PlArray(new PlString(s)));
    }
    public static final PlObject exit(int want, PlArray List__) {
        int arg = List__.aget(0).to_int();
        System.exit(arg);
        return PlCx.UNDEF;
    }
    public static final PlObject warn(int want, PlArray List__) {
        for (int i = 0; i < List__.to_int(); i++) {
            System.err.print(List__.aget(i).toString());
        }
        System.err.println("");
        return PlCx.INT1;
    }
    public static final PlObject die(int want, PlArray List__) {
        PlObject arg = List__.aget(0);
        if (arg.is_undef() || (arg.is_string() && arg.toString() == "")) {
            throw new PlDieException(PlCx.DIED);
        }
        if (List__.to_int() == 1) {
            throw new PlDieException(arg);
        }
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < List__.to_int(); i++) {
            String item = List__.aget(i).toString();
            sb.append(item);
        }
        throw new PlDieException(new PlString(sb.toString()));
    }
    public static final PlObject die(String s) {
        // die() shortcut
        return PlCORE.die(PlCx.VOID, new PlArray(new PlString(s)));
    }
    public static final PlString ref(int want, PlArray List__) {
        return List__.aget(0).ref();
    }
    public static final PlObject values(int want, PlObject List__) {
        return want == PlCx.LIST ? List__.values() : List__.values().scalar();
    }
    public static final PlObject keys(int want, PlObject List__) {
        return want == PlCx.LIST ? List__.keys() : List__.keys().scalar();
    }
    public static final PlObject each(int want, PlObject List__) {
        return want == PlCx.LIST ? List__.each() : List__.each().aget(0);
    }
    public static final PlObject scalar(int want, PlArray List__) {
        if (List__.to_int() == 0) {
            return PlCx.UNDEF;
        }
        return List__.aget(-1).scalar();
    }
    public static final PlObject join(int want, PlArray List__) {
        String s = List__.shift().toString();
        StringBuilder sb = new StringBuilder();
        boolean first = true;
        for (int i = 0; i < List__.to_int(); i++) {
            String item = List__.aget(i).toString();
            if (first)
                first = false;
            else
                sb.append(s);
            sb.append(item);
        }
        return new PlString(sb.toString());
    }
    public static final PlObject reverse(int want, PlArray List__) {
        if (want == PlCx.LIST) {
            PlArray ret = new PlArray(List__);
            Collections.reverse(ret.a);
            return ret;
        }
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < List__.to_int(); i++) {
            sb.append( List__.aget(i).toString() );
        }
        return new PlString(sb.reverse().toString());
    }
    public static final PlObject time(int want, PlArray List__) {
        return new PlDouble( System.currentTimeMillis() * 0.001 );
    }
    public static final PlObject sleep(int want, PlArray List__) {
        long s = (new Double(List__.shift().to_double() * 1000)).longValue();
        try {
            TimeUnit.MILLISECONDS.sleep(s);
        } catch (InterruptedException e) {
            //Handle exception
        }
        return new PlDouble(s / 1000.0);
    }
    public static final PlObject system(int want, PlArray List__) {
        // TODO - see perldoc -f system
        try {
            String[] args = new String[List__.to_int()];
            int i = 0;
            for (PlObject s : List__.a) {
                args[i++] = s.toString();
            }
            String s = null;
            Process p = Runtime.getRuntime().exec(args);
            // BufferedReader stdInput = new BufferedReader(new InputStreamReader(p.getInputStream()));
            // BufferedReader stdError = new BufferedReader(new InputStreamReader(p.getErrorStream()));
            // System.out.println("STDOUT\n");
            // while ((s = stdInput.readLine()) != null) {
            //     System.out.println("  " + s);
            // }
            // System.out.println("STDERR\n");
            // while ((s = stdError.readLine()) != null) {
            //     System.out.println("  " + s);
            // }
            return PlCx.INT0;
        }
        catch (IOException e) {
            // System.out.println("IOexception: ");
            // e.printStackTrace();
            return PlCx.MIN1;
        }
    }
    public static final PlObject qx(int want, PlArray List__) {
        // TODO - see perldoc -f qx
        try {
            String[] args = new String[List__.to_int()];
            int i = 0;
            for (PlObject s : List__.a) {
                args[i++] = s.toString();
            }
            PlArray res = new PlArray();
            String s = null;
            Process p = Runtime.getRuntime().exec(args);
            BufferedReader stdInput = new BufferedReader(new InputStreamReader(p.getInputStream()));
            System.out.println("STDOUT\n");
            while ((s = stdInput.readLine()) != null) {
                // System.out.println("  " + s);
                res.push(s + "\n");
            }
            // BufferedReader stdError = new BufferedReader(new InputStreamReader(p.getErrorStream()));
            // System.out.println("STDERR\n");
            // while ((s = stdError.readLine()) != null) {
            //     System.out.println("  " + s);
            // }
            if (want == PlCx.LIST) {
                return res;
            }
            res.unshift(PlCx.EMPTY);
            return join(want, res);
        }
        catch (IOException e) {
            // System.out.println("IOexception: ");
            // e.printStackTrace();
            return PlCx.UNDEF;
        }
    }
}
class PerlCompare implements Comparator<PlObject> {
    public PlClosure sorter;
    public PlLvalue v_a;
    public PlLvalue v_b;
    public PerlCompare (PlClosure sorter, PlLvalue a, PlLvalue b) {
        this.sorter = sorter;
        this.v_a = a;
        this.v_b = b;
    }
    public int compare (PlObject a, PlObject b) {
        v_a.set(a);
        v_b.set(b);
        return this.sorter.apply( PlCx.SCALAR, new PlArray() ).to_int();
    }
}
class PerlOp {
    // PerlOp implements operators: && || 
    //      and auxiliary functions
    //
    // note: '+' add() and '-' sub() are PlObject methods, not implemented here.
    //
    // TODO - see Perlito5/Javascript2/Runtime.pm for more operator implementations
    // TODO - 'boolean_stack' should be reset when an exception happens

    private static ArrayList<PlObject> boolean_stack = new ArrayList<PlObject>();
    private static PlArray local_stack = new PlArray();
    private static Random random = new Random();

    // objects
    // coderef methods can be called on ANY invocant
    //  $m = sub {...};
    //  $a->$m
    public static final PlObject call( PlObject invocant, PlObject method, PlArray args, int context ) {
        if ( method.is_coderef() ) {
            args.unshift(invocant);
            return method.apply(context, args);
        }
        else if ( method.is_lvalue() ) {
            return call( invocant, method.get(), args, context );
        }
        else {
            return call( invocant, method.toString(), args, context );
        }
    }
    public static final PlObject call( String invocant, PlObject method, PlArray args, int context ) {
        if ( method.is_coderef() ) {
            args.unshift( new PlString(invocant) );
            return method.apply(context, args);
        }
        else if ( method.is_lvalue() ) {
            return call( invocant, method.get(), args, context );
        }
        else {
            return call( invocant, method.toString(), args, context );
        }
    }
    // Intermediate calls, which have to be dispatched properly
    public static final PlObject call( PlObject invocant, String method, PlArray args, int context ) {
        if ( invocant.is_undef() ) {
            PlCORE.die( "Can't call method \"" + method
                + "\" on an undefined value" );
            return PlCx.UNDEF;
        }

        if ( invocant.is_lvalue() ) {
            invocant = invocant.get();
        }

        PlClass pClass = invocant.blessed();

        if ( pClass == null ) {
            PlCORE.die( "Can't call method \"" + method
                + "\" on unblessed reference" );
            return PlCx.UNDEF;
        }
        else {
            return call( pClass.className().toString(), method, args, context );
        }
    }
    public static final PlObject call( String invocant, String method, PlArray args, int context ) {
        if ( invocant.equals("") ) {
            PlCORE.die( "Can't call method \"" + method
                + "\" on an undefined value" );
            return PlCx.UNDEF;
        }

        PlObject methodCode = PlV.get(invocant + "::" + method);

        if (methodCode.is_undef()) {
            PlCORE.die( "Can't locate object method \"" + method
                + "\" via package \"" + invocant
                + "\" (perhaps you forgot to load \"" + invocant + "\"?" );
            return PlCx.UNDEF;
        }

        args.unshift( new PlString(invocant) );
        return methodCode.apply(context, args);
    }

    // local()
    public static final PlObject push_local(PlHash container, String index) {
        local_stack.a.add(container);
        local_stack.a.add(new PlString(index));
        PlLvalue empty = new PlLvalue();
        local_stack.a.add(container.hget_lvalue(index));
        container.h.put(index, empty);
        return empty;
    }
    public static final PlObject push_local(PlArray container, int index) {
        local_stack.a.add(container);
        local_stack.a.add(new PlInt(index));
        PlLvalue empty = new PlLvalue();
        local_stack.a.add(container.aget_lvalue(index));
        container.aset(index, empty);
        return empty;
    }
    public static final int local_length() {
        return local_stack.to_int();
    }
    public static final PlObject cleanup_local(int pos, PlObject ret) {
        while (local_stack.to_int() > pos) {
            PlLvalue lvalue    = (PlLvalue)local_stack.pop();
            PlObject index     = local_stack.pop();
            PlObject container = local_stack.pop();
            if (container.is_array()) {
                ((PlArray)container).a.set(index.to_int(), lvalue);
            }
            else {
                ((PlHash)container).h.put(index.toString(), lvalue);
            }
        }
        return ret;
    }

    // context()
    //      - handles run-time scalar/list/void context in expression results
    public static final PlObject context(int want, PlObject arg) {
        if (want == PlCx.LIST) {
            return arg;
        }
        return arg.scalar();
    }
    public static final PlObject context(int want) {
        if (want == PlCx.LIST) {
            return new PlArray();
        }
        return PlCx.UNDEF;
    }
    public static final PlObject context(int want, PlObject... args) {
        if (want == PlCx.LIST) {
            return new PlArray(args);
        }
        return args[args.length-1].scalar();
    }

    // statement()
    //      - workaround for "Error: not a statement"
    //      - this is the compile-time version of context(null, arg)
    public static final void statement(PlObject arg) { }
    public static final void statement() { }

    // control-flow exceptions
    public static final PlObject next() {
        throw PlCx.NEXT;
    }
    public static final PlObject next(int label_id) {
        throw new PlNextException(label_id);
    }
    public static final PlObject last() {
        throw PlCx.LAST;
    }
    public static final PlObject last(int label_id) {
        throw new PlLastException(label_id);
    }
    public static final PlObject redo(int label_id) {
        throw new PlRedoException(label_id);
    }
    public static final PlObject ret(PlObject ret) {
        throw new PlReturnException(ret);
    }

    public static final PlObject caller(int ctx, PlObject s) {
        int item = s.to_int();
        PlCORE.die("caller() not implemented");
        return null;
    }

    public static final PlObject srand() {
        random = new Random();
        return PlCx.UNDEF;
    }
    public static final PlObject srand(int s) {
        random = new Random(s);
        return new PlInt(s);
    }

    public static final PlObject rand(double s) {
        if (s == 0.0) {
            s = 1.0;
        }
        return new PlDouble(s * random.nextDouble());
    }

    public static final long[] range(PlObject _start, PlObject _end, int ctx, String var, int ignore) {
        if (ctx == PlCx.LIST) {
            long start = _start.to_long(),
                 end   = _end.to_long();
            int size = Math.max(0, (int)(end - start + 1));
            long[] ret = new long[size];
            for (int i = 0; i < size; ++i) {
                ret[i] = start + i;
            }
            return ret;
        }
        PlCORE.die("Range not implemented for context " + ctx);
        return null;
    }

    public static final PlObject smartmatch_scalar(PlObject arg0, PlObject arg1) {
        if (arg1.is_undef()) {
            return arg0.is_undef() ? PlCx.TRUE : PlCx.FALSE;
        }
        if (arg1.is_string()) {
            return arg0.str_eq(arg1);
        }
        if (arg1.is_num() || arg1.is_int()) {
            return arg0.num_eq(arg1);
        }
        return PlCORE.die(PlCx.VOID, new PlArray(new PlString("Not implemented: smartmatch operator with argument type '"), PlCORE.ref(PlCx.SCALAR, new PlArray(arg1)), new PlString("'")));
    }

    // and1(x) ? y : and3()
    public static final boolean and1(PlObject arg1) {
        if (arg1.to_bool()) {
            return true;
        }
        else {
            boolean_stack.add(0, arg1);
            return false;
        }
    }
    public static final PlObject and3() {
        return boolean_stack.remove(0);
    }

    // or1(x) ? or2() : y
    public static final boolean or1(PlObject arg1) {
        if (arg1.to_bool()) {
            boolean_stack.add(0, arg1);
            return true;
        }
        else {
            return false;
        }
    }
    public static final PlObject or2() {
        return boolean_stack.remove(0);
    }

    // defined_or1(x) ? defined_or2() : y
    public static final boolean defined_or1(PlObject arg1) {
        if (!arg1.is_undef()) {
            boolean_stack.add(0, arg1);
            return true;
        }
        else {
            return false;
        }
    }
    public static final PlObject defined_or2() {
        return boolean_stack.remove(0);
    }

    public static final PlInt ord(PlString s) {
        String item = s.toString();
        return new PlInt(item.length() > 0 ? Character.codePointAt(item, 0) : 0);
    }

    public static final PlString string_replicate(PlObject s, PlObject c) {
        int count = c.to_int();
        if ( count < 1 ) {
            return new PlString("");
        }
        else {
            String raw_s = s.toString();
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < count; i++) {
                sb.append(raw_s);
            }
            return new PlString(sb.toString());
        }
    }
    public static final PlObject list_replicate(PlArray o, PlObject c, int wantarray) {
        int count = c.to_int();
        PlArray a = new PlArray();
        if (count > 0) {
            for (int i = 0; i < count; i++) {
                a.push( o );
            }
        }
        return (wantarray == PlCx.LIST ) ? a : a.length_of_array();
    }
    public static final PlObject grep(PlClosure c, PlArray a, int wantarray) {
        PlArray ret = new PlArray();
        int size = a.to_int();
        PlLvalue v__ref = (PlLvalue)PlV.get("main::v__");
        PlObject v__val = v__ref.get();
        for (int i = 0; i < size; i++) {
            boolean result;
            PlObject temp = a.aget(i);
            v__ref.set(temp);
            result = c.apply(PlCx.SCALAR, new PlArray()).to_bool();
            if (result) {
                ret.push(temp);
            }
        }
        v__ref.set(v__val);
        return (wantarray == PlCx.LIST ) ? ret : ret.length_of_array();
    }
    public static final PlObject map(PlClosure c, PlArray a, int wantarray) {
        PlArray ret = new PlArray();
        int size = a.to_int();
        PlLvalue v__ref = (PlLvalue)PlV.get("main::v__");
        PlObject v__val = v__ref.get();
        for (int i = 0; i < size; i++) {
            v__ref.set(a.aget(i));
            ret.push(c.apply(PlCx.LIST, new PlArray()));
        }
        v__ref.set(v__val);
        return (wantarray == PlCx.LIST ) ? ret : ret.length_of_array();
    }
    public static final PlObject sort(PlClosure c, PlArray a, int wantarray, String pckg) {
        PlArray ret = new PlArray(a);
        int size = a.to_int();
        PlLvalue v_a_ref = (PlLvalue)PlV.get(pckg + "::v_a");
        PlLvalue v_b_ref = (PlLvalue)PlV.get(pckg + "::v_b");
        PerlCompare comp = new PerlCompare(c, v_a_ref, v_b_ref);
        PlObject v_a_val = v_a_ref.get();
        PlObject v_b_val = v_b_ref.get();
        Collections.sort(ret.a, comp);
        v_a_ref.set(v_a_val);
        v_b_ref.set(v_b_val);
        return (wantarray == PlCx.LIST ) ? ret : ret.length_of_array();
    }
    public static final PlObject match(PlObject s, PlRegex pat, int want) {
        if (want != PlCx.LIST) {
            return pat.p.matcher(s.toString()).find() ? PlCx.TRUE : PlCx.FALSE;
        }
        PlArray ret = new PlArray();
        Matcher matcher = pat.p.matcher(s.toString());
        while (matcher.find()) {
            for (int i = 1; i <= matcher.groupCount(); i++) {
                ret.push(matcher.group(i));
            }
        }
        return ret;
    }
    public static final PlObject match(PlObject s, PlLvalue pat, int want) {
        return match(s, pat.get(), want);
    }
    public static final PlObject match(PlObject s, PlObject pat, int want) {
        // TODO - cache the compiled pattern
        return match(s, new PlRegex(pat, 0), want);
    }

    public static final PlObject replace(PlLvalue s, PlRegex pat, PlObject rep, int want) {
        if (want != PlCx.LIST) {
            return s.set(new PlString(pat.p.matcher(s.toString()).replaceAll(rep.toString())));
        }
        PlCORE.die("not implemented string replace in list context");
        return s;
    }
    public static final PlObject replace(PlObject s, PlObject pat, PlObject rep, int want) {
        // TODO - cache the compiled pattern
        return replace(s, new PlRegex(pat, 0), rep, want);
    }

}
class PlV {
    // PlV implements namespaces and global variables
    //
    // TODO - import CORE subroutines in new namespaces, if needed
    // TODO - cache lookups in lexical variables (see PlClosure implementation)

    public static final PlHash var = new PlHash();

    public static final PlLvalue get(String name) {
        return (PlLvalue)var.hget_lvalue(name);
    }
    public static final PlLvalue get_local(String name) {
        return (PlLvalue)var.hget_lvalue_local(name);
    }
    public static final PlObject set(String name, PlObject v) {
        return var.hset(name, v);
    }
    public static final PlObject set_local(String name, PlObject v) {
        return var.hget_lvalue_local(name).set(v);
    }

    public static final PlHash hash_get(String name) {
        return (PlHash)var.hget_hashref(name).get();
    }
    public static final PlHash hash_get_local(String name) {
        return (PlHash)var.hget_lvalue_local(name).get_hashref().get();
    }
    public static final PlObject hash_set(String name, PlObject v) {
        return var.hget_hashref(name).hash_deref_set(v);
    }
    public static final PlObject hash_set_local(String name, PlObject v) {
        return var.hget_lvalue_local(name).get_hashref().hash_deref_set(v);
    }

    public static final PlArray array_get(String name) {
        return (PlArray)var.hget_arrayref(name).get();
    }
    public static final PlArray array_get_local(String name) {
        return (PlArray)var.hget_lvalue_local(name).get_arrayref().get();
    }
    public static final PlObject array_set(String name, PlObject v) {
        return var.hget_arrayref(name).array_deref_set(v);
    }
    public static final PlObject array_set_local(String name, PlObject v) {
        return var.hget_lvalue_local(name).get_arrayref().array_deref_set(v);
    }
}
class PlEnv {
    public static final void init(String[] args) {
        PlV.array_set(PlCx.ARGV, new PlArray(args));               // args is String[]
        PlV.hash_set(PlCx.ENV,   new PlArray(System.getenv()));    // env  is Map<String, String>
        PlV.set("main::v_" + (char)34, new PlString(" "));         // $" = " "
    }
}
class PlObject {
    public static final PlString REF = new PlString("");

    public PlObject() {
    }
EOT
        # add interfaces to Java classes
        # that were declared with
        #
        #   package MyJavaClass { Java }
        #
    . join('', ( map {
                    my $class = $_;
                    my $java_class_name = $class->{java_type};
                    my $perl_to_java = $class->{perl_to_java};
                    $class->{import} || $class->{extends} ? 
                    "    public ${java_class_name} ${perl_to_java}() {\n"
                  . "        PlCORE.die(\"error .${perl_to_java}!\");\n"
                  . "        return null;\n"
                  . "    }\n" : ()
            }
            values %java_classes
      ))
    . <<'EOT'
    // public String toString() {
    //     return this.toString();
    // }
    public int to_int() {
        long v = this.to_long();
        if (v > Integer.MAX_VALUE || v < Integer.MIN_VALUE) {
            PlCORE.die("numeric overflow converting to int");
        }
        return (int)v;
    }
    public byte to_byte() {
        long v = this.to_long();
        if (v > Byte.MAX_VALUE || v < Byte.MIN_VALUE) {
            PlCORE.die("numeric overflow converting to byte");
        }
        return (byte)v;
    }
    public short to_short() {
        long v = this.to_long();
        if (v > Short.MAX_VALUE || v < Short.MIN_VALUE) {
            PlCORE.die("numeric overflow converting to short");
        }
        return (short)v;
    }
    public float to_float() {
        double v = this.to_double();
        return (float)v;
    }
    public long to_long() {
        PlCORE.die("error .to_long!");
        return 0;
    }
    public PlObject end_of_array_index() {
        return PlCORE.die("Not an ARRAY reference");
    }
    public double to_double() {
        PlCORE.die("error .to_double!");
        return 0.0;
    }
    public boolean to_bool() {
        PlCORE.die("error .to_bool!");
        return true;
    }
    public boolean is_undef() {
        return false;
    }
    public PlObject apply(int want, PlArray List__) {
        // $ perl -e ' $a = 5; $a->() '
        // Undefined subroutine &main::5 called
        PlCORE.die("subroutine call error");
        return this;
    }

    public PlObject length() {
        return new PlInt(this.toString().length());
    }
    public PlObject get_arrayref() {
        return PlCORE.die("Not an ARRAY reference");
    }

    public PlObject shift() {
        return PlCORE.die("Not an ARRAY reference");
    }

    public PlObject get_hashref() {
        return PlCORE.die("Not a HASH reference");
    }

    public PlObject hget_scalarref(PlObject i) {
        PlCORE.die("Not a SCALAR reference");
        return this;
    }
    public PlObject hget_scalarref(String i) {
        PlCORE.die("Not a SCALAR reference");
        return this;
    }
    public PlObject scalar_deref_set(PlObject v) {
        PlCORE.die("Not a SCALAR reference");
        return this;
    }
    public PlObject aget_scalarref(PlObject i) {
        PlCORE.die("Not a SCALAR reference");
        return this;
    }
    public PlObject aget_scalarref(int i) {
        PlCORE.die("Not a SCALAR reference");
        return this;
    }

    public PlObject array_deref() {
        PlCORE.die("Not an ARRAY reference");
        return this;
    }
    public PlObject array_deref_set(PlObject i) {
        PlCORE.die("Not an ARRAY reference");
        return this;
    }

    public PlObject hget_arrayref(PlObject i) {
        PlCORE.die("Not a HASH reference");
        return this;
    }
    public PlObject hget_arrayref(String i) {
        PlCORE.die("Not a HASH reference");
        return this;
    }
    public PlObject hget_hashref(PlObject i) {
        PlCORE.die("Not a HASH reference");
        return this;
    }
    public PlObject hget_hashref(String i) {
        PlCORE.die("Not a HASH reference");
        return this;
    }

    public PlObject aget_arrayref(PlObject i) {
        PlCORE.die("Not an ARRAY reference");
        return this;
    }
    public PlObject aget_arrayref(int i) {
        PlCORE.die("Not an ARRAY reference");
        return this;
    }
    public PlObject aget_hashref(PlObject i) {
        PlCORE.die("Not an ARRAY reference");
        return this;
    }
    public PlObject aget_hashref(int i) {
        PlCORE.die("Not an ARRAY reference");
        return this;
    }

    public PlObject hash_deref() {
        PlCORE.die("Not a HASH reference");
        return this;
    }
    public PlObject hash_deref_set(PlObject i) {
        PlCORE.die("Not a HASH reference");
        return this;
    }

    public PlObject hget(PlObject i) {
        PlCORE.die("Not a HASH reference");
        return this;
    }
    public PlObject hget(String i) {
        PlCORE.die("Not a HASH reference");
        return this;
    }
    public PlObject hget_lvalue(PlObject i) {
        PlCORE.die("Not a HASH reference");
        return this;
    }
    public PlObject hget_lvalue(String i) {
        PlCORE.die("Not a HASH reference");
        return this;
    }
    public PlObject hget_lvalue_local(PlObject i) {
        PlCORE.die("Not a HASH reference");
        return this;
    }
    public PlObject hget_lvalue_local(String i) {
        PlCORE.die("Not a HASH reference");
        return this;
    }

    public PlObject hset(PlObject s, PlObject v) {
        PlCORE.die("Not a HASH reference");
        return this;
    }
    public PlObject hset(String s, PlObject v) {
        PlCORE.die("Not a HASH reference");
        return this;
    }

    public PlObject aget(PlObject i) {
        PlCORE.die("Not an ARRAY reference");
        return this;
    }
    public PlObject aget(int i) {
        PlCORE.die("Not an ARRAY reference");
        return this;
    }
    public PlObject aset(int i, PlObject v) {
        PlCORE.die("Not an ARRAY reference");
        return this;
    }
    public PlObject aset(PlObject i, PlObject v) {
        PlCORE.die("Not an ARRAY reference");
        return this;
    }
    public PlObject to_array() {
        PlCORE.die("Not an ARRAY reference");
        return this;
    }
    public PlObject length_of_array() {
        PlCORE.die("Not an ARRAY reference");
        return this;
    }
    public PlObject values() {
        PlCORE.die("Type of argument to values on reference must be unblessed hashref or arrayref");
        return this;
    }
    public PlObject keys() {
        PlCORE.die("Type of argument to keys on reference must be unblessed hashref or arrayref");
        return this;
    }
    public PlObject each() {
        PlCORE.die("Type of argument to each on reference must be unblessed hashref or arrayref");
        return this;
    }
    public PlObject exists(PlObject i) {
        PlCORE.die("exists argument is not a HASH or ARRAY element or a subroutine");
        return this;
    }
    public PlObject delete(PlObject i) {
        PlCORE.die("delete argument is not a HASH or ARRAY element or slice");
        return this;
    }
    public PlObject set(PlObject o) {
        PlCORE.die("Modification of a read-only value attempted");
        return this;
    }
    public PlObject get() {
        PlCORE.die("error .get!");
        return this;
    }
    public boolean is_int() {
        return false;
    }
    public boolean is_num() {
        return false;
    }
    public boolean is_string() {
        return false;
    }
    public boolean is_bool() {
        return false;
    }
    public boolean is_hash() {
        return false;
    }
    public boolean is_array() {
        return false;
    }
    public boolean is_lvalue() {
        return false;
    }
    public boolean is_ref() {
        return false;
    }
    public boolean is_scalarref() {
        return false;
    }
    public boolean is_arrayref() {
        return false;
    }
    public boolean is_hashref() {
        return false;
    }
    public boolean is_coderef() {
        return false;
    }
    public PlString ref() {
		return REF;
    }
    public PlObject _decr() {
        // --$x
        return PlCx.MIN1;
    }
    public PlObject _incr() {
        // ++$x
        return PlCx.INT1;
    }
    public PlObject neg() {
        return new PlInt(-this.to_long());
    }
    public PlObject abs() {
        long c = this.to_long();
        return new PlInt(c < 0 ? -c : c);
    }

    public PlObject sqrt() { return new PlDouble(Math.sqrt(this.to_double())); }
    public PlObject cos()  { return new PlDouble(Math.cos(this.to_double())); }
    public PlObject sin()  { return new PlDouble(Math.sin(this.to_double())); }
    public PlObject exp()  { return new PlDouble(Math.exp(this.to_double())); }
    public PlObject log()  { return new PlDouble(Math.log(this.to_double())); }
    public PlObject pow(PlObject arg)    { return new PlDouble(Math.pow(this.to_double(), arg.to_double())); }
    public PlObject atan2(PlObject arg)  { return new PlDouble(Math.atan2(this.to_double(), arg.to_double())); }

    public PlObject pre_decr() {
        // --$x
        PlCORE.die("Can't modify constant item in predecrement (--)");
        return this;
    }
    public PlObject post_decr() {
        // $x--
        PlCORE.die("Can't modify constant item in postdecrement (--)");
        return this;
    }
    public PlObject pre_incr() {
        // ++$x
        PlCORE.die("Can't modify constant item in preincrement (++)");
        return this;
    }
    public PlObject post_incr() {
        // $x++
        PlCORE.die("Can't modify constant item in postincrement (++)");
        return this;
    }

    public PlObject lcfirst() {
        String s = this.toString();
        int len = s.length();
        if (len == 0) {
            return new PlString(s);
        }
        if (len == 1) {
            return new PlString(s.toLowerCase());
        }
        return new PlString( s.substring(0,1).toLowerCase() + s.substring(1) );
    }
    public PlObject ucfirst() {
        String s = this.toString();
        int len = s.length();
        if (len == 0) {
            return new PlString(s);
        }
        if (len == 1) {
            return new PlString(s.toUpperCase());
        }
        return new PlString( s.substring(0,1).toUpperCase() + s.substring(1) );
    }
    public PlObject quotemeta() {
        String s = this.toString();
        return new PlString(Matcher.quoteReplacement(s));
    }

    public PlObject substr(PlObject offset) {
        // substr EXPR,OFFSET
        String s = this.toString();
        int ofs = offset.to_int();
        if (ofs < 0) {
            ofs = s.length() + ofs;
        }
        if (ofs < 0) {
            ofs = 0;
        }
        if (ofs >= s.length()) {
            return PlCx.UNDEF;
        }
        return new PlString(s.substring(ofs));
    }
    public PlObject substr(PlObject offset, PlObject length) {
        // substr EXPR,OFFSET,LENGTH
        String s = this.toString();
        int ofs = offset.to_int();
        int len = length.to_int();
        if (ofs < 0) {
            ofs = s.length() + ofs;
        }
        if (ofs >= s.length()) {
            return PlCx.UNDEF;
        }

        if (len < 0) {
            len = s.length() + len;
        }
        else {
            len = ofs + len;
        }

        if (len >= s.length()) {
            len = s.length();
        }
        if (len <= 0) {
            return PlCx.UNDEF;
        }
        if (ofs < 0) {
            ofs = 0;
        }
        return new PlString(s.substring(ofs, len));
    }
    public PlObject substr(PlObject offset, PlObject length, PlObject replacement) {
        // substr EXPR,OFFSET,LENGTH,REPLACEMENT
        PlCORE.die("TODO substr EXPR,OFFSET,LENGTH,REPLACEMENT");
        return this;
    }
    public PlObject bless(PlString className) {
		PlCORE.die("Can't bless non-reference value");
		return this;
    }
    public PlClass blessed() {
		return null;
    }
    public PlObject scalar() {
        return this;
    }
    public PlObject str_cmp(PlObject b) {
        int c = this.toString().compareTo(b.toString());
        return new PlInt(c == 0 ? c : c < 0 ? -1 : 1);
    }
    public PlObject num_cmp(PlObject b) {
        return b.num_cmp2(this);
    }
    public PlObject num_cmp2(PlObject b) {
        Long blong = new Long(b.to_long());
        int c = blong.compareTo(this.to_long());
        return new PlInt(c == 0 ? c : c < 0 ? -1 : 1);
    }
EOT
    . ( join('', map {
            my $perl = $_;
            my $native  = $number_binop{$perl}{op};
            my $returns = $number_binop{$perl}{returns};
"    public PlObject ${perl}(PlObject s) {
        return s.${perl}2(this);
    }
"
    .   ( $returns eq 'PlDouble' ?
"    public PlObject ${perl}2(PlObject s) {
        return new ${returns}( s.to_double() ${native} this.to_double() );
    }
"
        :
"    public PlObject ${perl}2(PlObject s) {
        return new ${returns}( s.to_long() ${native} this.to_long() );
    }
"       )
            }
            keys %number_binop ))

    . ( join('', map {
            my $perl = $_;
            my $native  = $string_binop{$perl}{op};
            my $returns = $string_binop{$perl}{returns};
"    public PlObject ${perl}(PlObject b) {
        return new ${returns}(this.toString().compareTo(b.toString()) ${native});
    }
"
            }
            keys %string_binop ))

    . <<'EOT'
}
class PlReference extends PlObject {
    public static final PlString REF = new PlString("REF");
	public PlClass bless;

    public boolean is_ref() {
        return true;
    }
    public PlReference bless(PlString className) {
        this.bless = new PlClass(className);
        return this;
    }
    public PlClass blessed() {
		return this.bless;
    }

	public PlString ref() {
		if ( this.bless == null ) {
			return REF;
		}
		else {
			return this.bless.className();
		}
	}

    public String toString() {
        return this.ref().toString() + "(0x" + Integer.toHexString(this.hashCode()) + ")";
    }
}
class PlRegex extends PlReference {
    public Pattern p;
    // public Matcher m;
    public static final PlString REF = new PlString("Regexp");

    public PlRegex(String p, int flags) {
        this.p = Pattern.compile(p, flags);
    }
    public PlRegex(PlObject p, int flags) {
        this.p = Pattern.compile(p.toString(), flags);
    }
    public String toString() {
        // TODO - show flags
        return this.p.toString();
    }
}
class PlClosure extends PlReference implements Runnable {
    public PlObject[] env;       // new PlObject[]{ v1, v2, v3 }
    public PlObject prototype;    // '$$$'
    public static final PlString REF = new PlString("CODE");

    public PlClosure(PlObject prototype, PlObject[] env) {
        this.prototype = prototype;
        this.env = env;
    }
    // Note: apply() is inherited from PlObject
    public PlObject apply(int want, PlArray List__) {
        PlCORE.die("it looks like you have a closure without a block");
        return this;
    }
    public void run() {
        // run as a thread
        this.apply(PlCx.VOID, new PlArray());
    }
	public PlString ref() {
		if ( this.bless == null ) {
			return REF;
		}
		else {
			return this.bless.className();
		}
	}
    public boolean is_coderef() {
        return true;
    }
}
class PlLvalueRef extends PlReference {
    private PlObject o;
    public static final PlString REF = new PlString("SCALAR");

	public PlString ref() {
		if ( this.bless == null ) {
			return REF;
		}
		else {
			return this.bless.className();
		}
	}
    public String toString() {
        int id = System.identityHashCode(this.o);
        return this.ref().toString() + "(0x" + Integer.toHexString(id) + ")";
    }
    public PlLvalueRef(PlLvalue o) {
        this.o = o;
    }
    public PlLvalueRef(PlObject o) {
        this.o = o;
    }
    public PlObject scalar_deref_set(PlObject v) {
        return this.o.set(v);
    }
    public boolean is_scalarref() {
        return true;
    }
    public PlObject get() {
        return this.o;
    }
}
class PlArrayRef extends PlArray {
    public static final PlString REF = new PlString("ARRAY");
	public PlClass bless;

    public String toString() {
        int id = System.identityHashCode(this.a);
        return this.ref().toString() + "(0x" + Integer.toHexString(id) + ")";
    }
    public PlArrayRef() {
        this.each_iterator = 0;
        this.a = new ArrayList<PlObject>();
    }
    public PlArrayRef(PlArray o) {
        this.a = o.a;
        this.each_iterator = o.each_iterator;
    }
    public PlObject set(PlArray o) {
        this.a = o.a;
        this.each_iterator = o.each_iterator;
        return o;
    }
    public PlObject get() {
        PlArray o = new PlArray();
        o.a = this.a;
        return o;
    }
    public PlObject array_deref() {
        PlArray o = new PlArray();
        o.a = this.a;
        return o;
    }
    public PlObject array_deref_set(PlObject v) {
        super.set(v);
        return v;
    }
    public boolean is_array() {
        return false;
    }
    public boolean is_ref() {
        return true;
    }
    public boolean is_arrayref() {
        return true;
    }
    public PlObject scalar() {
        return this;
    }
    public PlArrayRef bless(PlString className) {
        this.bless = new PlClass(className);
        return this;
    }
    public PlClass blessed() {
		return this.bless;
    }
	public PlString ref() {
		if ( this.bless == null ) {
			return REF;
		}
		else {
			return this.bless.className();
		}
	}
}
class PlHashRef extends PlHash {
    public static final PlString REF = new PlString("HASH");
	public PlClass bless;

    public String toString() {
        int id = System.identityHashCode(this.h);
        return this.ref().toString() + "(0x" + Integer.toHexString(id) + ")";
    }
    public PlHashRef() {
        this.h = new HashMap<String, PlObject>();
        this.each_iterator = null;
    }
    public PlHashRef(PlHash o) {
        this.h = o.h;
        this.each_iterator = o.each_iterator;
    }
    public PlObject set(PlHash o) {
        this.h = o.h;
        this.each_iterator = o.each_iterator;
        return o;
    }
    public PlObject get() {
        PlHash o = new PlHash();
        o.h = this.h;
        return o;
    }
    public PlObject hash_deref() {
        PlHash o = new PlHash();
        o.h = this.h;
        return o;
    }
    public PlObject hash_deref_set(PlObject v) {
        super.set(v);
        return v;
    }
    public boolean is_hash() {
        return false;
    }
    public boolean is_ref() {
        return true;
    }
    public boolean is_hashref() {
        return true;
    }
    public PlObject scalar() {
        return this;
    }
    public PlHashRef bless(PlString className) {
        this.bless = new PlClass(className);
        return this;
    }
    public PlClass blessed() {
		return this.bless;
    }
    public PlString ref() {
		if ( this.bless == null ) {
			return REF;
		}
		else {
			return this.bless.className();
		}
	}
}
class PlClass {
	public static PlHash classes = new PlHash();
	public PlString className;

	public PlClass (PlString blessing) {
		this.className = blessing;
		if (classes.exists(className) == null) {
			classes.hset(className, className);
		}
	}
	public PlString className() {
		return this.className;
	}
    public boolean is_undef() {
        return this.className == null;
    }
}
class PlLvalue extends PlObject {
    private PlObject o;

    // Note: several versions of PlLvalue()
    public PlLvalue() {
        this.o = PlCx.UNDEF;
    }
    public PlLvalue(PlObject o) {
        this.o = o;
    }
    public PlLvalue(PlLvalue o) {
        this.o = o.get();
    }
    public PlLvalue(PlArray o) {
        // $a = @x
        this.o = o.scalar();
    }
    public PlLvalue(PlHash o) {
        // $a = %x
        this.o = o.scalar();
    }
    public PlObject get() {
        return this.o;
    }
    public PlObject get_scalarref() {
        if (this.o.is_undef()) {
            PlLvalueRef ar = new PlLvalueRef(new PlLvalue());
            this.o = ar;
            return ar;
        }
        else if (this.o.is_scalarref()) {
            return this.o;
        }
        // Modification of a read-only value attempted
        return this.o;
    }
    public PlObject get_arrayref() {
        if (this.o.is_undef()) {
            PlArrayRef ar = new PlArrayRef();
            this.o = ar;
            return ar;
        }
        else if (this.o.is_arrayref()) {
            return this.o;
        }
        return PlCORE.die("Not an ARRAY reference");
    }
    public PlObject get_hashref() {
        if (this.o.is_undef()) {
            PlHashRef hr = new PlHashRef();
            this.o = hr;
            return this.o;
        }
        else if (this.o.is_hashref()) {
            return this.o;
        }
        return PlCORE.die("Not a HASH reference");
    }
    public PlObject aget(PlObject i) {
        return this.o.aget(i);
    }
    public PlObject aget(int i) {
        return this.o.aget(i);
    }

    public PlObject aget_scalarref(PlObject i) {
        if (this.o.is_undef()) {
            this.o = new PlArrayRef();
        }
        return this.o.aget_scalarref(i);
    }
    public PlObject aget_arrayref(PlObject i) {
        if (this.o.is_undef()) {
            this.o = new PlArrayRef();
        }
        return this.o.aget_arrayref(i);
    }
    public PlObject aget_hashref(PlObject i) {
        if (this.o.is_undef()) {
            this.o = new PlArrayRef();
        }
        return this.o.aget_hashref(i);
    }

    public PlObject aset(int i, PlObject v) {
        return this.o.aset(i, v);
    }
    public PlObject aset(PlObject i, PlObject v) {
        return this.o.aset(i, v);
    }
    public PlObject hget(PlObject i) {
        return this.o.hget(i);
    }
    public PlObject hget(String i) {
        return this.o.hget(i);
    }

    public PlObject hget_scalarref(PlObject i) {
        if (this.o.is_undef()) {
            this.o = new PlHashRef();
        }
        return this.o.hget_scalarref(i);
    }
    public PlObject hget_arrayref(PlObject i) {
        if (this.o.is_undef()) {
            this.o = new PlHashRef();
        }
        return this.o.hget_arrayref(i);
    }
    public PlObject hget_hashref(PlObject i) {
        if (this.o.is_undef()) {
            this.o = new PlHashRef();
        }
        return this.o.hget_hashref(i);
    }

    public PlObject hset(PlObject s, PlObject v) {
        return this.o.hset(s, v);
    }
    public PlObject hset(String s, PlObject v) {
        return this.o.hset(s, v);
    }

    public PlObject scalar_deref() {
        return this.get_scalarref().get();
    }
    public PlObject scalar_deref_set(PlObject v) {
        return this.get_scalarref().scalar_deref_set(v);
    }

    public PlObject array_deref() {
        // @$x doesn't autovivify
        if (this.o.is_undef()) {
            return new PlArray();
        }
        else if (this.o.is_arrayref()) {
            return this.o.get();
        }
        return PlCORE.die("Not an ARRAY reference");
    }
    public PlObject array_deref_set(PlObject v) {
        // @$x = ...
        if (this.o.is_undef()) {
            this.o = new PlArrayRef();
            return this.o.array_deref_set(v);
        }
        else if (this.o.is_arrayref()) {
            return this.o.array_deref_set(v);
        }
        return PlCORE.die("Not an ARRAY reference");
    }

    public PlObject hash_deref() {
        // %$x doesn't autovivify
        if (this.o.is_undef()) {
            return new PlHash();
        }
        else if (this.o.is_hashref()) {
            return this.o.get();
        }
        return PlCORE.die("Not a HASH reference");
    }
    public PlObject hash_deref_set(PlObject v) {
        // %$x = ...
        if (this.o.is_undef()) {
            this.o = new PlHashRef();
            return this.o.hash_deref_set(v);
        }
        else if (this.o.is_hashref()) {
            return this.o.hash_deref_set(v);
        }
        return PlCORE.die("Not a HASH reference");
    }
    public PlObject apply(int want, PlArray List__) {
        return this.o.apply(want, List__);
    }

    // Note: several versions of set()
    public PlObject set(PlObject o) {
        if (o == null) {
            o = PlCx.UNDEF;
        }
        this.o = o;
        return this;
    }
    public PlObject set(PlLvalue o) {
        this.o = o.get();
        return this;
    }
    public PlObject set(PlArray o) {
        // $a = @x
        this.o = o.scalar();
        return this;
    }
    public PlObject set(PlHash o) {
        // $a = %x
        this.o = o.scalar();
        return this;
    }
EOT
    . ( join('', map {
            my $native = $_;
            my $perl   = $native_to_perl{$native};
            $native && $perl ? 
"    public PlObject set($native s) {
        this.o = new $perl(s);
        return this;
    }
" : ()
            }
            keys %native_to_perl ))

    . <<'EOT'
    public String toString() {
        return this.o.toString();
    }
    public long to_long() {
        return this.o.to_long();
    }
    public double to_double() {
        return this.o.to_double();
    }
    public boolean to_bool() {
        return this.o.to_bool();
    }
    public PlObject num_cmp(PlObject b) {
        return this.o.num_cmp(b);
    }
    public PlObject num_cmp2(PlObject b) {
        return b.num_cmp(this.o);
    }
EOT
    . ( join('', map {
            my $perl = $_;
            my $native = $number_binop{$perl}{op};
"    public PlObject ${perl}(PlObject s) {
        return this.o.${perl}(s);
    }
    public PlObject ${perl}2(PlObject s) {
        return s.${perl}(this.o);
    }
"
            }
            keys %number_binop ))

    . <<'EOT'
    public boolean is_int() {
        return this.o.is_int();
    }
    public boolean is_num() {
        return this.o.is_num();
    }
    public boolean is_string() {
        return this.o.is_string();
    }
    public boolean is_bool() {
        return this.o.is_bool();
    }
    public boolean is_undef() {
        return this.o.is_undef();
    }
    public boolean is_lvalue() {
        return true;
    }
    public boolean is_coderef() {
        return this.o.is_coderef();
    }

    public PlObject pre_decr() {
        // --$x
        this.o = this.o._decr();
        return this.o;
    }
    public PlObject post_decr() {
        // $x--
        PlObject res = this.o;
        this.o = this.o._decr();
        return res;
    }
    public PlObject pre_incr() {
        // ++$x
        this.o = this.o._incr();
        return this.o;
    }
    public PlObject post_incr() {
        // $x++
        PlObject res = this.o;
        this.o = this.o._incr();
        return res;
    }
    public PlObject neg() {
        return this.o.neg();
    }
    public PlObject abs() {
        return this.o.abs();
    }
    public PlObject scalar() {
        return this.o;
    }
    public PlObject bless(PlString className) {
        return this.o.bless(className);
    }
    public PlClass blessed() {
		return this.o.blessed();
    }
    public PlString ref() {
        return this.o.ref();
    }
EOT
        # add "unbox" accessors to Java classes
        # that were declared with
        #
        #   package MyJavaClass { Java }
        #
    . join('', ( map {
                    my $class = $_;
                    my $java_class_name = $class->{java_type};
                    my $perl_to_java = $class->{perl_to_java};
                    $class->{import} || $class->{extends} ? 
"    public ${java_class_name} ${perl_to_java}() {
        return this.o.${perl_to_java}();
    }
" : ()
            }
            values %java_classes
      ))

    . <<'EOT'
}
class PlArray extends PlObject {
    public ArrayList<PlObject> a;
    public int each_iterator;
    public PlArray( ArrayList<PlObject> a ) {
        this.each_iterator = 0;
        this.a = a;
    }
    public PlArray() {
        this.each_iterator = 0;
        this.a = new ArrayList<PlObject>();
    }
    public PlArray(PlObject... args) {
        ArrayList<PlObject> aa = new ArrayList<PlObject>();
        for (PlObject s : args) {
            if (s.is_hash()) {
                // @x = %x;
                s = s.to_array();
            }
            if (s.is_array()) {
                // @x = ( @x, @y );
                for (int i = 0; i < s.to_long(); i++) {
                    aa.add(s.aget(i));
                }
            }
            else {
                aa.add(s);
            }
        }
        this.each_iterator = 0;
        this.a = aa;
    }
    public PlObject set(PlObject s) {
        this.a.clear();
        if (s.is_hash()) {
            // @x = %x;
            s = s.to_array();
        }
        if (s.is_array()) {
            // @x = ( @x, @y );
            for (int i = 0; i < s.to_long(); i++) {
                this.a.add(s.aget(i));
            }
        }
        else {
            this.a.add(s);
        }
        this.each_iterator = 0;
        return this;
    }
    public PlObject set(byte[] bs) {
        this.a.clear();
        // @x = byte[] native;
        for(byte b : bs){
            int i = b;
            this.a.add(new PlInt(i));
        }
        this.each_iterator = 0;
        return this;
    }
    public PlArray(byte[] bs) {
        PlArray aa = new PlArray();
        aa.set(bs);
        this.each_iterator = aa.each_iterator;
        this.a = aa.a;
    }

    public PlObject set(long[] longs) {
        this.a.clear();
        // @x = long[] native;
        for(long i : longs){
            this.a.add(new PlInt(i));
        }
        this.each_iterator = 0;
        return this;
    }
    public PlArray(long[] longs) {
        PlArray aa = new PlArray();
        aa.set(longs);
        this.each_iterator = aa.each_iterator;
        this.a = aa.a;
    }

    public PlObject set(int[] ints) {
        this.a.clear();
        // @x = int[] native;
        for(int i : ints){
            this.a.add(new PlInt(i));
        }
        this.each_iterator = 0;
        return this;
    }
    public PlArray(int[] ints) {
        PlArray aa = new PlArray();
        aa.set(ints);
        this.each_iterator = aa.each_iterator;
        this.a = aa.a;
    }
    public PlObject set(String[] strings) {
        this.a.clear();
        for (String s : strings) {
            this.a.add(new PlString(s));
        }
        this.each_iterator = 0;
        return this;
    }
    public PlArray(String[] strings) {
        PlArray arr = new PlArray();
        arr.set(strings);
        this.each_iterator = arr.each_iterator;
        this.a = arr.a;
    }

    public PlObject set(Map<String, String> env) {
        this.a.clear();
        for (String envName : env.keySet()) {
            this.a.add(new PlString(envName));
            this.a.add(new PlString(env.get(envName)));
        }
        this.each_iterator = 0;
        return this;
    }
    public PlArray(Map<String, String> strings) {
        PlArray arr = new PlArray();
        arr.set(strings);
        this.each_iterator = arr.each_iterator;
        this.a = arr.a;
    }

    // TODO - Double[]
EOT
        # add "box" array-of Java classes
        # that were declared with
        #
        #   package MyJavaClass { Java }
        #
    . join('', ( map {
                    my $class = $_;
                    my $java_class_name = $class->{java_type};
                    my $perl_to_java    = $class->{perl_to_java};
                    my $perl_package    = $class->{perl_package};
                    my $java_native_to_perl = $class->{java_native_to_perl};
                    $class->{import} || $class->{extends} ? 
"    public PlObject set(${java_class_name}[] stuffs) {
        this.a.clear();
        // \@x = ${java_class_name}[] native;
        for(${java_class_name} i : stuffs){
            this.a.add(new ${java_native_to_perl}(i));
        }
        this.each_iterator = 0;
        return this;
    }
    public PlArray(${java_class_name}[] stuffs) {
        PlArray aa = new PlArray();
        aa.set(stuffs);
        this.each_iterator = aa.each_iterator;
        this.a = aa.a;
    }
" : ()
            }
            values %java_classes
      ))

    . <<'EOT'
    public PlObject aget(PlObject i) {
        int pos  = i.to_int();
        if (pos < 0) {
            pos = this.a.size() + pos;
        }
        if (pos < 0 || pos >= this.a.size()) {
            return PlCx.UNDEF;
        }
        return this.a.get(pos);
    }
    public PlObject aget(int i) {
        int pos  = i;
        if (pos < 0) {
            pos = this.a.size() + pos;
        }
        if (pos < 0 || pos >= this.a.size()) {
            return PlCx.UNDEF;
        }
        return this.a.get(pos);
    }
    public PlObject aget_lvalue(int pos) {
        int size = this.a.size();
        if (pos < 0) {
            pos = size + pos;
        }
        if (size <= pos) {
            while (size < pos) {
                this.a.add( PlCx.UNDEF );
                size++;
            }
            PlLvalue a = new PlLvalue();
            this.a.add(a);
            return a;
        }
        PlObject o = this.a.get(pos);
        if (o == null) {
            PlLvalue a = new PlLvalue();
            this.a.set(pos, a);
            return a;
        }
        else if (o.is_lvalue()) {
            return o;
        }
        PlLvalue a = new PlLvalue(o);
        this.a.set(pos, a);
        return a;
    }
    public PlObject aget_lvalue(PlObject i) {
        return this.aget_lvalue(i.to_int());
    }
    public PlObject aget_lvalue_local(PlObject i) {
        return this.aget_lvalue_local(i.to_int());
    }
    public PlObject aget_lvalue_local(int i) {
        return PerlOp.push_local(this, i);
    }

    public PlObject get_scalar(PlObject i) {
        // $$x
        PlObject o = this.aget(i);
        if (o.is_undef()) {
            PlLvalue a = new PlLvalue();
            this.aset(i, new PlLvalueRef(a));
            return a;
        }
        else if (o.is_scalarref()) {
            return o.get();
        }
        // Modification of a read-only value attempted
        // return PlCORE.die("Not an SCALAR reference");
        return o;
    }
    public PlObject aget_scalarref(PlObject i) {
        PlObject o = this.aget(i);
        if (o.is_undef()) {
            PlLvalueRef ar = new PlLvalueRef(new PlLvalue());
            this.aset(i, ar);
            return ar;
        }
        else if (o.is_scalarref()) {
            return o;
        }
        return PlCORE.die("Not a SCALAR reference");
    }
    public PlObject aget_scalarref(int i) {
        PlObject o = this.aget(i);
        if (o.is_undef()) {
            PlLvalueRef ar = new PlLvalueRef(new PlLvalue());
            this.aset(i, ar);
            return ar;
        }
        else if (o.is_scalarref()) {
            return o;
        }
        return PlCORE.die("Not a SCALAR reference");
    }

    public PlObject aget_arrayref(PlObject i) {
        PlObject o = this.aget(i);
        if (o.is_undef()) {
            PlArrayRef ar = new PlArrayRef();
            this.aset(i, ar);
            return ar;
        }
        else if (o.is_arrayref()) {
            return o;
        }
        return PlCORE.die("Not an ARRAY reference");
    }
    public PlObject aget_arrayref(int i) {
        PlObject o = this.aget(i);
        if (o.is_undef()) {
            PlArrayRef ar = new PlArrayRef();
            this.aset(i, ar);
            return ar;
        }
        else if (o.is_arrayref()) {
            return o;
        }
        return PlCORE.die("Not an ARRAY reference");
    }

    public PlObject aget_hashref(PlObject i) {
        PlObject o = this.aget(i);
        if (o.is_undef()) {
            PlHashRef hr = new PlHashRef();
            this.aset(i, hr);
            return hr;
        }
        else if (o.is_hashref()) {
            return o;
        }
        return PlCORE.die("Not a HASH reference");
    }
    public PlObject aget_hashref(int i) {
        PlObject o = this.aget(i);
        if (o.is_undef()) {
            PlHashRef hr = new PlHashRef();
            this.aset(i, hr);
            return hr;
        }
        else if (o.is_hashref()) {
            return o;
        }
        return PlCORE.die("Not a HASH reference");
    }

    public PlObject get_hash(int i) {
        PlObject o = this.aget(i);
        if (o.is_undef()) {
            PlHashRef hr = new PlHashRef();
            this.aset(i, hr);
            return hr;
        }
        else if (o.is_hashref()) {
            return o;
        }
        return PlCORE.die("Not a HASH reference");
    }

    // Note: multiple versions of set()
    public PlObject aset(PlObject i, PlObject v) {
        int size = this.a.size();
        int pos  = i.to_int();
        if (pos < 0) {
            pos = size + pos;
        }
        if (size <= pos) {
            while (size < pos) {
                this.a.add( PlCx.UNDEF );
                size++;
            }
            this.a.add(v.scalar());
            return v;
        }
        this.a.set(pos, v.scalar());
        return v;
    }
    public PlObject aset(int i, PlObject v) {
        int size = this.a.size();
        int pos  = i;
        if (pos < 0) {
            pos = size + pos;
        }
        if (size <= pos) {
            while (size < pos) {
                this.a.add( PlCx.UNDEF );
                size++;
            }
            this.a.add(v.scalar());
            return v;
        }
        this.a.set(pos, v.scalar());
        return v;
    }
    public PlObject aset(PlObject i, PlLvalue v) {
        int size = this.a.size();
        int pos  = i.to_int();
        if (pos < 0) {
            pos = size + pos;
        }
        if (size <= pos) {
            while (size < pos) {
                this.a.add( PlCx.UNDEF );
                size++;
            }
            this.a.add(v.scalar());
            return v;
        }
        this.a.set(pos, v.get());
        return v;
    }
    public PlObject aset(int i, PlLvalue v) {
        int size = this.a.size();
        int pos  = i;
        if (pos < 0) {
            pos = size + pos;
        }
        if (size <= pos) {
            while (size < pos) {
                this.a.add( PlCx.UNDEF );
                size++;
            }
            this.a.add(v.scalar());
            return v;
        }
        this.a.set(pos, v.get());
        return v;
    }
EOT
    . ( join('', map {
            my $native = $_;
            my $perl   = $native_to_perl{$native};
            $native && $perl ?
"    public PlObject aset(PlObject i, $native s) {
        return this.aset(i, new $perl(s));
    }
    public PlObject aset(int i, $native s) {
        return this.aset(i, new $perl(s));
    }
    public PlObject push($native s) {
        this.a.add(new $perl(s));
        return this.length_of_array();
    }
" : ()
            }
            keys %native_to_perl ))

    . <<'EOT'

    // Note: multiple versions of push()
    public PlObject push(PlObject v) {
        if (v.is_array()) {
            return this.push( (PlArray)v );
        }
        this.a.add(v.scalar());
        return this.length_of_array();
    }
    public PlObject push(PlLvalue v) {
        this.a.add(v.get());
        return this.length_of_array();
    }
    public PlObject push(PlArray args) {
        for (int i = 0; i < args.to_int(); i++) {
            PlObject s = args.aget(i);
            if (s.is_hash()) {
                // @x = %x;
                s = s.to_array();
            }
            if (s.is_array()) {
                this.push(s);
            }
            else {
                this.a.add(s);
            }
        }
        return this.length_of_array();
    }

    // Note: multiple versions of unshift()
    public PlObject unshift(PlObject v) {
        if (v.is_array()) {
            return this.unshift( (PlArray)v );
        }
        this.a.add(0, v.scalar());
        return this.length_of_array();
    }
    public PlObject unshift(PlLvalue v) {
        this.a.add(0, v.get());
        return this.length_of_array();
    }
    public PlObject unshift(PlArray args) {
        for (int i = args.to_int() - 1; i >= 0; i--) {
            PlObject s = args.aget(i);
            if (s.is_hash()) {
                // @x = %x;
                s = s.to_array();
            }
            if (s.is_array()) {
                this.unshift(s);
            }
            else {
                this.a.add(0, s);
            }
        }
        return this.length_of_array();
    }

    public PlObject pop() {
        int size = this.a.size() - 1;
        if (size >= 0) {
            return this.a.remove(size);
        }
        else {
            return PlCx.UNDEF;
        }
    }
    public PlObject shift() {
        int size = this.a.size();
        if (size > 0) {
            return this.a.remove(0);
        }
        else {
            return PlCx.UNDEF;
        }
    }
    public PlObject exists(PlObject i) {
        PlCORE.die("TODO - array exists");
        return this;
    }
    public PlObject delete(PlObject i) {
        PlCORE.die("TODO - array delete");
        return this;
    }
    public PlObject values() {
        // return a copy
        return new PlArray(this);
    }
    public PlObject keys() {
        PlArray aa = new PlArray();
        int size = this.a.size();
        for (int i = 0; i < size; i++) {
            aa.push(new PlInt(i));
        }
        return aa;
    }
    public PlObject each() {
        PlArray aa = new PlArray();
        int size = this.a.size();
        if (this.each_iterator < size) {
            aa.push(new PlInt(this.each_iterator));
            aa.push(this.aget(this.each_iterator));
            this.each_iterator++;
        }
        else {
            // return empty list
            this.each_iterator = 0;
        }
        return aa;
    }
    public String toString() {
        StringBuilder sb = new StringBuilder();
        int size = this.a.size();
        for (int i = 0; i < size; i++) {
            String item = this.a.get(i).toString();
            sb.append(item);
        }
        return sb.toString();
    }
    public long to_long() {
        return this.a.size();
    }
    public int to_int() {
        return this.a.size();
    }
    public PlObject length_of_array() {
        return new PlInt(this.a.size());
    }
    public PlObject end_of_array_index() {
        return new PlInt(this.a.size() - 1);
    }
    public double to_double() {
        return 0.0 + this.to_long();
    }
    public boolean to_bool() {
        return (this.a.size() > 0);
    }
    public boolean is_int() {
        return false;
    }
    public boolean is_num() {
        return false;
    }
    public boolean is_string() {
        return false;
    }
    public boolean is_bool() {
        return false;
    }
    public boolean is_array() {
        return true;
    }
    public PlObject scalar() {
        return this.length_of_array();
    }
}
class PlHash extends PlObject {
    public HashMap<String, PlObject> h;
    public Iterator<Map.Entry<String, PlObject>> each_iterator;

    public PlHash() {
        this.each_iterator = null;
        this.h = new HashMap<String, PlObject>();
    }
    public PlHash(PlObject... args) {
        PlHash hh = new PlHash();
        int args_size = args.length;
        for (int i = 0; i < args_size; i++) {
            PlObject s = args[i];
            if (s.is_hash()) {
                // @x = %x;
                s = s.to_array();
            }
            if (s.is_array()) {
                // %x = ( @x, @y );
                int array_size = s.to_int();
                for (int j = 0; j < array_size; j++) {
                    PlObject key = s.aget(j);
                    j++;
                    PlObject value;
                    if ( j >= array_size ) {
                        // TODO - emit warning about odd number of arguments
                        value = PlCx.UNDEF;
                    }
                    else {
                        value = s.aget(j);
                    }
                    hh.hset(key, value);
                }
            }
            else {
                i++;
                PlObject value;
                if ( i >= args_size ) {
                    // TODO - emit warning about odd number of arguments
                    value = PlCx.UNDEF;
                }
                else {
                    value = args[i];
                }
                hh.hset(s, value);
            }
        }
        this.each_iterator = null;
        this.h = hh.to_HashMap();
    }
    private HashMap<String, PlObject> to_HashMap() {
        return this.h;
    }
    public PlObject set(PlObject s) {
        this.h.clear();
        if (s.is_hash()) {
            // @x = %x;
            s = s.to_array();
        }
        if (s.is_array()) {
            // %x = ( @x, @y );
            int array_size = s.to_int();
            for (int j = 0; j < array_size; j++) {
                PlObject key = s.aget(j);
                j++;
                PlObject value;
                if ( j >= array_size ) {
                    // TODO - emit warning about odd number of arguments
                    value = PlCx.UNDEF;
                }
                else {
                    value = s.aget(j);
                }
                this.hset(key, value);
            }
        }
        else {
            // TODO - emit warning about odd number of arguments
            this.hset(s, PlCx.UNDEF);
        }
        this.each_iterator = null;
        return this;
    }

    public PlObject to_array() {
        PlArray aa = new PlArray();
        for (Map.Entry<String, PlObject> entry : this.h.entrySet()) {
            String key = entry.getKey();
            PlObject value = entry.getValue();
            aa.push(new PlString(key));
            aa.push(value);
        }
        return aa;
    }

    public PlObject hget(PlObject i) {
        PlObject o = this.h.get(i.toString());
        if (o == null) {
            return PlCx.UNDEF;
        }
        return o;
    }
    public PlObject hget(String i) {
        PlObject o = this.h.get(i);
        if (o == null) {
            return PlCx.UNDEF;
        }
        return o;
    }
    public PlObject hget(int want, PlArray a) {
        PlArray aa = new PlArray();

        for (int i = 0; i < a.to_int(); i++) {
            PlObject r = this.hget(a.aget(i));
            aa.push(r);
        }
        if (want == PlCx.LIST) {
            return aa;
        }
        return aa.pop();
    }

    public PlObject hget_lvalue(PlObject i) {
        PlObject o = this.h.get(i.toString());
        if (o == null) {
            PlLvalue a = new PlLvalue();
            this.h.put(i.toString(), a);
            return a;
        }
        else if (o.is_lvalue()) {
            return o;
        }
        PlLvalue a = new PlLvalue(o);
        this.h.put(i.toString(), a);
        return a;
    }
    public PlObject hget_lvalue(String i) {
        PlObject o = this.h.get(i);
        if (o == null) {
            PlLvalue a = new PlLvalue();
            this.h.put(i, a);
            return a;
        }
        else if (o.is_lvalue()) {
            return o;
        }
        PlLvalue a = new PlLvalue(o);
        this.h.put(i, a);
        return a;
    }
    public PlObject hget_lvalue_local(PlObject i) {
        return this.hget_lvalue_local(i.toString());
    }
    public PlObject hget_lvalue_local(String i) {
        return PerlOp.push_local(this, i);
    }

    public PlObject get_scalar(PlObject i) {
        // $$x
        PlObject o = this.hget(i);
        if (o.is_undef()) {
            PlLvalue a = new PlLvalue();
            this.hset(i, new PlLvalueRef(a));
            return a;
        }
        else if (o.is_scalarref()) {
            return o.get();
        }
        // Modification of a read-only value attempted
        // return PlCORE.die("Not an SCALAR reference");
        return o;
    }

    public PlObject hget_scalarref(PlObject i) {
        PlObject o = this.hget(i);
        if (o.is_undef()) {
            PlLvalueRef ar = new PlLvalueRef(new PlLvalue());
            this.hset(i, ar);
            return ar;
        }
        else if (o.is_scalarref()) {
            return o;
        }
        // Modification of a read-only value attempted
        return o;
    }
    public PlObject hget_scalarref(String i) {
        PlObject o = this.hget(i);
        if (o.is_undef()) {
            PlLvalueRef ar = new PlLvalueRef(new PlLvalue());
            this.hset(i, ar);
            return ar;
        }
        else if (o.is_scalarref()) {
            return o;
        }
        // Modification of a read-only value attempted
        return o;
    }

    public PlObject hget_arrayref(PlObject i) {
        PlObject o = this.hget(i);
        if (o.is_undef()) {
            PlArrayRef ar = new PlArrayRef();
            this.hset(i, ar);
            return ar;
        }
        else if (o.is_arrayref()) {
            return o;
        }
        return PlCORE.die("Not an ARRAY reference");
    }
    public PlObject hget_arrayref(String i) {
        PlObject o = this.hget(i);
        if (o.is_undef()) {
            PlArrayRef ar = new PlArrayRef();
            this.hset(i, ar);
            return ar;
        }
        else if (o.is_arrayref()) {
            return o;
        }
        return PlCORE.die("Not an ARRAY reference");
    }

    public PlObject hget_hashref(PlObject i) {
        PlObject o = this.hget(i);
        if (o.is_undef()) {
            PlHashRef hr = new PlHashRef();
            this.hset(i, hr);
            return hr;
        }
        else if (o.is_hashref()) {
            return o;
        }
        return PlCORE.die("Not a HASH reference");
    }
    public PlObject hget_hashref(String i) {
        PlObject o = this.hget(i);
        if (o.is_undef()) {
            PlHashRef hr = new PlHashRef();
            this.hset(i, hr);
            return hr;
        }
        else if (o.is_hashref()) {
            return o;
        }
        return PlCORE.die("Not a HASH reference");
    }

    // Note: multiple versions of set()
    public PlObject hset(PlObject s, PlObject v) {
        String key = s.toString();
        PlObject value = v.scalar();
        PlObject o = this.h.get(key);
        if (o != null && o.is_lvalue()) {
            o.set(value);
        }
        else {
            this.h.put(key, value);
        }
        return v;
    }
    public PlObject hset(String key, PlObject v) {
        PlObject value = v.scalar();
        PlObject o = this.h.get(key);
        if (o != null && o.is_lvalue()) {
            o.set(value);
        }
        else {
            this.h.put(key, value);
        }
        return v;
    }
    public PlObject hset(PlObject s, PlLvalue v) {
        return this.hset(s, v.get());
    }
    public PlObject hset(String s, PlLvalue v) {
        return this.hset(s, v.get());
    }
    public PlObject hset(int want, PlArray s, PlArray v) {
        PlArray aa = new PlArray();

        for (int i = 0; i < v.to_int(); i++){
            aa.push(this.hset(v.aget(i), s.aget(i)));
        };
        if (want == PlCx.LIST) {
            return aa;
        }
        return aa.pop();
    }

    public PlObject exists(PlObject i) {
        return this.h.containsKey(i) ? PlCx.TRUE : PlCx.FALSE;
    }
    public PlObject delete(PlObject i) {
        PlObject r = this.h.remove(i.toString());
        if (r == null) {
            return PlCx.UNDEF;
        }
        return r;
    }
    public PlObject delete(int want, PlArray a) {
        PlArray aa = new PlArray();

        for (int i = 0; i < a.to_int(); i++) {
            PlObject r = this.delete(a.aget(i));
            aa.push(r);
        }
        if (want == PlCx.LIST) {
            return aa;
        }
        return aa.pop();
    }
    public PlObject values() {
        PlArray aa = new PlArray();
        for (Map.Entry<String, PlObject> entry : this.h.entrySet()) {
            PlObject value = entry.getValue();
            aa.push(value);
        }
        return aa;
    }
    public PlObject keys() {
        PlArray aa = new PlArray();
        for (Map.Entry<String, PlObject> entry : this.h.entrySet()) {
            String key = entry.getKey();
            aa.push(new PlString(key));
        }
        return aa;
    }
    public PlObject each() {
        if (this.each_iterator == null) {
            this.each_iterator = this.h.entrySet().iterator();
        }
        PlArray aa = new PlArray();
        if (this.each_iterator.hasNext()) {
            Map.Entry<String, PlObject> entry = this.each_iterator.next();
            String key = entry.getKey();
            aa.push(new PlString(key));
            PlObject value = entry.getValue();
            aa.push(value);
        }
        else {
             // return empty list
             this.each_iterator = null;
        }
        return aa;
    }
EOT
    . ( join('', map {
            my $native = $_;
            my $perl   = $native_to_perl{$native};
            $native && $perl ?
"    public PlObject hset(PlObject s, $native v) {
        return this.hset(s, new $perl(v));
    }
    public PlObject hset(String s, $native v) {
        return this.hset(s, new $perl(v));
    }
" : ()
            }
            keys %native_to_perl ))

    . <<'EOT'

    public String toString() {
        // TODO
        return "" + this.hashCode();
    }
    public long to_long() {
        // TODO
        return this.hashCode();
    }
    public double to_double() {
        return 0.0 + this.to_long();
    }
    public boolean to_bool() {
        return true;
    }
    public boolean is_int() {
        return false;
    }
    public boolean is_num() {
        return false;
    }
    public boolean is_string() {
        return false;
    }
    public boolean is_bool() {
        return false;
    }
    public boolean is_hash() {
        return true;
    }
    public PlObject scalar() {
        return new PlString(this.toString());
    }
}
class PlUndef extends PlObject {
    public PlUndef() {
    }
    public PlObject apply(int want, PlArray List__) {
        // $a->()
        PlCORE.die("Can't use an undefined value as a subroutine reference");
        return this;
    }
    public PlObject length() {
        return PlCx.UNDEF;
    }
    public long to_long() {
        return 0;
    }
    public double to_double() {
        return 0.0;
    }
    public String toString() {
        return "";
    }
    public boolean to_bool() {
        return false;
    }
    public boolean is_bool() {
        return false;
    }
    public boolean is_undef() {
        return true;
    }
}
class PlBool extends PlObject {
    private boolean i;
    public PlBool(boolean i) {
        this.i = i;
    }
    public long to_long() {
        if (this.i) {
            return 1;
        }
        else {
            return 0;
        }
    }
    public double to_double() {
        if (this.i) {
            return 1.0;
        }
        else {
            return 0.0;
        }
    }
    public String toString() {
        if (this.i) {
            return "1";
        }
        else {
            return "";
        }
    }
    public boolean to_bool() {
        return this.i;
    }
    public boolean is_bool() {
        return true;
    }
    public PlObject _decr() {
        // --$x
        if (i) {
            return PlCx.INT0;
        }
        else {
            return PlCx.MIN1;
        }
    }
    public PlObject _incr() {
        // ++$x
        if (i) {
            return new PlInt(2);
        }
        else {
            return PlCx.INT1;
        }
    }
    public PlObject neg() {
        if (i) {
            return PlCx.MIN1;
        }
        else {
            return PlCx.INT0;
        }
    }
}
class PlInt extends PlObject {
    private long i;
    public PlInt(long i) {
        this.i = i;
    }
    public PlInt(int i) {
        this.i = (long)i;
    }
    public long to_long() {
        return this.i;
    }
    public double to_double() {
        return (double)(this.i);
    }
    public String toString() {
        return "" + this.i;
    }
    public boolean to_bool() {
        return this.i != 0;
    }
    public boolean is_int() {
        return true;
    }
    public PlObject _decr() {
        // --$x
        return new PlInt(i-1);
    }
    public PlObject _incr() {
        // ++$x
        return new PlInt(i+1);
    }
    public PlObject neg() {
        return new PlInt(-i);
    }
}
class PlDouble extends PlObject {
    private double i;
    public PlDouble(double i) {
        this.i = i;
    }
    public long to_long() {
        return (long)(this.i);
    }
    public double to_double() {
        return this.i;
    }
    public String toString() {
        String s = "" + this.i;
        final int length = s.length();
        final int dot = s.indexOf('.');
        if (dot == -1) {
            return s;
        }
        for (int i = dot + 1; i < length; ++i) {
            if (s.charAt(i) != '0') {
                return s;
            }
        }
        return s.substring(0, dot);
    }
    public boolean to_bool() {
        return this.i != 0.0;
    }
    public PlObject _decr() {
        // --$x
        return new PlDouble(i-1);
    }
    public PlObject _incr() {
        // ++$x
        return new PlDouble(i+1);
    }
    public PlObject neg() {
        return new PlDouble(-i);
    }
    public PlObject abs() {
        return new PlDouble(i < 0.0 ? -i : i);
    }
    public PlObject num_cmp(PlObject b) {
        int c = new Double(this.i).compareTo(b.to_double());
        return new PlInt(c == 0 ? c : c < 0 ? -1 : 1);
    }
    public PlObject num_cmp2(PlObject b) {
        int c = new Double(b.to_double()).compareTo(this.i);
        return new PlInt(c == 0 ? c : c < 0 ? -1 : 1);
    }
EOT
    . ( join('', map {
            my $perl = $_;
            my $native  = $number_binop{$perl}{op};
            my $returns = $number_binop{$perl}{num_returns};
"    public PlObject ${perl}(PlObject s) {
        // num - int, num - num
        return new ${returns}( this.i ${native} s.to_double() );
    }
    public PlObject ${perl}2(PlObject s) {
        // int - num
        return new ${returns}( s.to_double() ${native} this.i );
    }
"
            }
            keys %number_binop ))

    . <<'EOT'
    public boolean is_num() {
        return true;
    }
}
class PlString extends PlObject {
    private java.lang.String s;
    private PlObject numericValue;
    private boolean hasValue;

    public PlString(String s) {
        this.s = s;
    }
    public PlString(char s) {
        this.s = "" + s;
    }
    public PlObject parse() {
        if (!hasValue) {
            hasValue = true;
            numericValue = this._parse();
        }
        return numericValue;
    }
    private PlObject _parse_exp(int length, int signal, int offset, int next) {
        // 123.45E^^^
        int offset3 = next;
        for ( ; offset3 < length; ) {
            final int c3 = s.codePointAt(offset3);
            switch (c3) {        
                case '+': case '-':
                    // TODO
                    break;
                case '0': case '1': case '2': case '3': case '4':
                case '5': case '6': case '7': case '8': case '9':
                    break;
                default:    // invalid
                    return new PlDouble(Double.parseDouble(this.s.substring(0, offset3)));
            }
            offset3++;
        }
        return new PlDouble(Double.parseDouble(this.s.substring(0, offset3)));
    }
    private PlObject _parse_dot(int length, int signal, int offset, int next) {
        // 123.^^^
        int offset3 = next;
        for ( ; offset3 < length; ) {
            final int c3 = s.codePointAt(offset3);
            switch (c3) {        
                case '0': case '1': case '2': case '3': case '4':
                case '5': case '6': case '7': case '8': case '9':
                    break;
                case 'E': case 'e':
                    // start exponential part
                    return _parse_exp(length, signal, offset, offset3+1);
                default:    // invalid
                    return new PlDouble(Double.parseDouble(this.s.substring(0, offset3)));
            }
            offset3++;
        }
        return new PlDouble(Double.parseDouble(this.s.substring(0, offset3)));
    }
    private PlObject _parse() {
        final int length = s.length();
        int signal = 0;
        for (int offset = 0; offset < length; ) {
            final int c = s.codePointAt(offset);
            switch (c) {        
                case 'i': case 'I':
                            if (this.s.substring(offset, offset+3).equalsIgnoreCase("inf")) {
                                if (signal < 0) {
                                    return new PlDouble(Double.NEGATIVE_INFINITY);
                                }
                                else {
                                    return new PlDouble(Double.POSITIVE_INFINITY);
                                }
                            }
                            return PlCx.INT0;
                case 'n': case 'N':
                            if (this.s.substring(offset, offset+3).equalsIgnoreCase("nan")) {
                                return new PlDouble(Double.NaN);
                            }
                            return PlCx.INT0;
                case '.':   // starts with dot
                            if (signal != 0) {
                                signal = 1;
                            }
                            return _parse_dot(length, signal, offset, offset+1);
                case '0': case '1': case '2': case '3': case '4':
                case '5': case '6': case '7': case '8': case '9':
                            // starts with number
                            if (signal == 0) {
                                signal = 1;
                            }
                            int offset2 = offset+1;
                            for ( ; offset2 < length; ) {
                                final int c2 = s.codePointAt(offset2);
                                switch (c2) {        
                                    case '0': case '1': case '2': case '3': case '4':
                                    case '5': case '6': case '7': case '8': case '9':
                                        // more numbers
                                        break;
                                    case '.':
                                        // start decimal part
                                        return _parse_dot(length, signal, offset, offset2+1);
                                    case 'E': case 'e':
                                        // start exponential part
                                        return _parse_exp(length, signal, offset, offset2+1);
                                    default:
                                        // return integer
                                        if (signal < 0) {
                                            return new PlInt(-Integer.parseInt(this.s.substring(offset, offset2)));
                                        }
                                        else {
                                            return new PlInt(Integer.parseInt(this.s.substring(offset, offset2)));
                                        }
                                }
                                offset2++;
                            }
                            // integer
                            if (signal < 0) {
                                return new PlInt(-Integer.parseInt(this.s.substring(offset, offset2)));
                            }
                            else {
                                return new PlInt(Integer.parseInt(this.s.substring(offset, offset2)));
                            }
                case '+':   // starts with +
                            if (signal != 0) {
                                // invalid
                                return PlCx.INT0;
                            }
                            signal = 1;
                            break;
                case '-':   // starts with -
                            if (signal != 0) {
                                // invalid
                                return PlCx.INT0;
                            }
                            signal = -1;
                            break;
                case ' ': case '\t': case '\n': case '\r':
                            // starts with space
                            if (signal != 0) {
                                // invalid
                                return PlCx.INT0;
                            }
                            break;
                default:    // invalid
                            return PlCx.INT0;
            }
            offset++;
        }
        return PlCx.INT0;
    }
    public long to_long() {
        return this.parse().to_long();
    }
    public double to_double() {
        return this.parse().to_double();
    }
    public String toString() {
        return this.s;
    }
    public boolean to_bool() {
        return this.s != ""
            && this.s != "0";
    }
    public boolean is_string() {
        return true;
    }
    public PlObject _decr() {
        // --$x
        return this.add(PlCx.MIN1);
    }

    // $x++ when $x is PlString
    private static final String _string_increment(String s) {
        if (s.length() < 2) {
            final int c = s.codePointAt(0);
            if ((c >= '0' && c <= '8') || (c >= 'A' && c <= 'Y') || (c >= 'a' && c <= 'y')) {
                return "" + (char)(c + 1);
            }
            if (c == '9') {
                return "10";
            }
            if (c == 'Z') {
                return "AA";
            }
            if (c == 'z') {
                return "aa";
            }
            return "1";
        }
        String c = _string_increment(s.substring(s.length()-1, s.length()));
        if (c.length() == 1) {
            return s.substring(0, s.length()-1) + c;
        }
        return _string_increment(s.substring(0, s.length()-1)) + c.substring(c.length()-1, c.length());
    }
    public PlObject _incr() {
        // ++$x
        final int length = s.length();
        if (length == 0) {
            return PlCx.INT1;
        }
        int c = this.s.codePointAt(0);
        switch (c) {        
            case ' ': case '\t': case '\n': case '\r':
            case '+': case '-': case '.':
            case '0': case '1': case '2': case '3': case '4':
            case '5': case '6': case '7': case '8': case '9':
                return this.add(PlCx.INT1);
        }
        c = s.codePointAt(length - 1);
        if ((c >= '0' && c <= '8') || (c >= 'A' && c <= 'Y') || (c >= 'a' && c <= 'y')) {
            return new PlString(s.substring(0, length-1) + (char)(c + 1));
        }
        return new PlString(_string_increment(this.s));
    }
    public PlObject neg() {
        final int length = s.length();
        if (length == 0) {
            return PlCx.INT0;
        }
        final int c = this.s.codePointAt(0);
        switch (c) {        
            case '+': case '-':
                if (c == '+') {
                    return new PlString( '-' + s.substring(1) );
                }
                if (c == '-') {
                    return new PlString( '+' + s.substring(1) );
                }
            case '.':
            case ' ': case '\t': case '\n': case '\r':
            case '0': case '1': case '2': case '3': case '4':
            case '5': case '6': case '7': case '8': case '9':
                return this.parse().neg();
        }
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) {
            return new PlString( '-' + s );
        }
        return PlCx.INT0;
    }
    public PlObject abs() {
        return this.parse().abs();
    }
    public PlObject num_cmp(PlObject b) {
        return this.parse().num_cmp(b);
    }
    public PlObject num_cmp2(PlObject b) {
        return b.num_cmp2(this.parse());
    }
EOT
    . ( join('', map {
            my $perl = $_;
            my $native  = $number_binop{$perl}{op};
            my $returns = $number_binop{$perl}{returns};
            my $num_returns = $number_binop{$perl}{num_returns};
            if ($returns eq 'PlDouble') {
"    public PlObject ${perl}(PlObject b) {
        // 'num' - int, 'num' - num
        return this.parse().${perl}(b);
    }
    public PlObject ${perl}2(PlObject b) {
        // int - 'num'
        return b.${perl}(this.parse());
    }
"
            }
            else {
"    public PlObject ${perl}(PlObject b) {
        // 'num' - int, 'num' - num
        return this.parse().${perl}(b);
    }
    public PlObject ${perl}2(PlObject b) {
        // int - 'num'
        return b.${perl}(this.parse());
    }
"
            }
            }
            keys %number_binop ))

    . <<'EOT'
}
EOT
        # add "box" classes to Java classes
        # that were declared with
        #
        #   package MyJavaClass { Java }
        #
    . join('', ( map {
                    my $class = $_;
                    my $java_class_name = $class->{java_type};
                    my $perl_to_java    = $class->{perl_to_java};
                    my $perl_package    = $class->{perl_package};
                    my $java_native_to_perl = $class->{java_native_to_perl};
                    $class->{import} || $class->{extends} ? 
"class ${java_native_to_perl} extends PlReference {
    public static final PlString REF = new PlString(\"${perl_package}\");
    private ${java_class_name} stuff;

    public ${java_native_to_perl}(${java_class_name} stuff) {
        this.stuff = stuff;
    }
    public ${java_class_name} ${perl_to_java}() {
        return this.stuff;
    }
    public PlString ref() {
		return REF;
    }
    public boolean is_undef() {
        return stuff == null;
    }
}
" : ()
            }
            values %java_classes
      ))

    . <<'EOT'
// end Perl-Java runtime
EOT

} # end of emit_java()

1;

__END__

=pod

=head1 NAME

Perlito5::Java::Runtime

=head1 DESCRIPTION

Provides runtime routines for the Perlito-in-Java compiled code

=head1 AUTHORS

Flavio Soibelmann Glock

=head1 COPYRIGHT

Copyright 2015 by Flavio Soibelmann Glock.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
