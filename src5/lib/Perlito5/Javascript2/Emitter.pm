use v5;

use Perlito5::AST;
use Perlito5::Dumper;
use strict;

package Perlito5::Javascript2;
{
    my %label;
    sub pkg {
        'p5pkg[' . Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME ) . ']'
    }
    sub get_label {
        'tmp' . $Perlito5::ID++
    }
    sub tab {
        my $level = shift;
        "\t" x $level
    }

    # prefix operators that take a "str" parameter
    our %op_prefix_js_str = (
        'prefix:<-A>' => 'p5atime',
        'prefix:<-C>' => 'p5ctime',
        'prefix:<-M>' => 'p5mtime',
        'prefix:<-d>' => 'p5is_directory',
        'prefix:<-e>' => 'p5file_exists',
        'prefix:<-f>' => 'p5is_file',
        'prefix:<-s>' => 'p5size',
        'prefix:<-p>' => 'p5is_pipe',
    );

    # these operators need 2 "str" parameters
    our %op_infix_js_str = (
        'infix:<eq>' => ' == ',
        'infix:<ne>' => ' != ',
        'infix:<le>' => ' <= ',
        'infix:<ge>' => ' >= ',
        'infix:<lt>' => ' < ',
        'infix:<gt>' => ' > ',
    );
    # these operators need 2 "num" parameters
    our %op_infix_js_num = (
        'infix:<==>' => ' == ',
        'infix:<!=>' => ' != ',
        'infix:<+>'  => ' + ',
        'infix:<->'  => ' - ',
        'infix:<*>'  => ' * ',
        'infix:</>'  => ' / ',
        # 'infix:<%>'  => ' % ',    # see p5modulo()
        'infix:<>>'  => ' > ',
        'infix:<<>'  => ' < ',
        'infix:<>=>' => ' >= ',
        'infix:<<=>' => ' <= ',
        'infix:<&>'  => ' & ',
        'infix:<|>'  => ' | ',
        'infix:<^>'  => ' ^ ',
        'infix:<>>>' => ' >>> ',
        # 'infix:<<<>' => ' << ',   # see p5shift_left()
    );
    # these operators always return "bool"
    our %op_to_bool = map +($_ => 1), qw(
        prefix:<!>
        infix:<!=>
        infix:<==>
        infix:<<=>
        infix:<>=>
        infix:<>>
        infix:<<>
        infix:<eq>
        infix:<ne>
        infix:<ge>
        infix:<le>
        infix:<gt>
        infix:<lt>
        infix:<~~>
        prefix:<not>
        exists
        defined
    );
    # these operators always return "string"
    our %op_to_str = map +($_ => 1), qw(
        substr
        join
        list:<.>
        chr
        lc
        uc
        lcfirst
        ucfirst
        ref
    );
    # these operators always return "num"
    our %op_to_num = map +($_ => 1), qw(
        length
        index
        ord
        oct
        infix:<->
        infix:<+>
        infix:<*>
        infix:</>
        infix:<%>
        infix:<**>
    );

    my %safe_char = (
        ' ' => 1,
        '!' => 1,
        '"' => 1,
        '#' => 1,
        '$' => 1,
        '%' => 1,
        '&' => 1,
        '(' => 1,
        ')' => 1,
        '*' => 1,
        '+' => 1,
        ',' => 1,
        '-' => 1,
        '.' => 1,
        '/' => 1,
        ':' => 1,
        ';' => 1,
        '<' => 1,
        '=' => 1,
        '>' => 1,
        '?' => 1,
        '@' => 1,
        '[' => 1,
        ']' => 1,
        '^' => 1,
        '_' => 1,
        '`' => 1,
        '{' => 1,
        '|' => 1,
        '}' => 1,
        '~' => 1,
    );

    sub escape_string {
        my $s = shift;
        my @out;
        my $tmp = '';
        return "''" if $s eq '';
        for my $i (0 .. length($s) - 1) {
            my $c = substr($s, $i, 1);
            if  (  ($c ge 'a' && $c le 'z')
                || ($c ge 'A' && $c le 'Z')
                || ($c ge '0' && $c le '9')
                || exists( $safe_char{$c} )
                )
            {
                $tmp = $tmp . $c;
            }
            else {
                push @out, "'$tmp'" if $tmp ne '';
                push @out, "String.fromCharCode(" . ord($c) . ")";
                $tmp = '';
            }
        }
        push @out, "'$tmp'" if $tmp ne '';
        return join(' + ', @out);
    }

    sub to_str {
            my $cond = shift;
            my $level = shift;
            my $wantarray = 'scalar';
            if (  $cond->isa( 'Perlito5::AST::Apply' ) && $cond->code eq 'circumfix:<( )>'
               && $cond->{arguments} && @{$cond->{arguments}}
               ) 
            {
                return to_str( $cond->{arguments}[0], $level )
            }

            if  (  ($cond->isa( 'Perlito5::AST::Buf' ))
                || ($cond->isa( 'Perlito5::AST::Apply' )  && exists $op_to_str{ $cond->code } )
                )
            {
                return $cond->emit_javascript2($level, $wantarray);
            }
            else {
                return 'p5str(' . $cond->emit_javascript2($level, $wantarray) . ')';
            }
    }
    sub is_num {
            my $cond = shift;
            return 1 if $cond->isa( 'Perlito5::AST::Int' )
                || $cond->isa( 'Perlito5::AST::Num' )
                || ($cond->isa( 'Perlito5::AST::Apply' )  && exists $op_to_num{ $cond->code } );
            return 0;
    }
    sub to_num {
            my $cond = shift;
            my $level = shift;
            my $wantarray = 'scalar';
            if ( is_num($cond) ) {
                return $cond->emit_javascript2($level, $wantarray);
            }
            else {
                return 'p5num(' . $cond->emit_javascript2($level, $wantarray) . ')';
            }
    }
    sub to_bool {
            my $cond = shift;
            my $level = shift;
            my $wantarray = 'scalar';

            if (  $cond->isa( 'Perlito5::AST::Apply' ) && $cond->code eq 'circumfix:<( )>'
               && $cond->{arguments} && @{$cond->{arguments}}
               ) 
            {
                return to_bool( $cond->{arguments}[0], $level )
            }

            # Note: 'infix:<||>' and 'infix:<&&>' can only be optimized here because we know we want "bool"
            if (  $cond->isa( 'Perlito5::AST::Apply' ) 
               && (  $cond->code eq 'infix:<&&>'
                  || $cond->code eq 'infix:<and>'
                  )
               ) 
            {
                return '(' . to_bool($cond->{arguments}->[0], $level) . ' && '
                           . to_bool($cond->{arguments}->[1], $level) . ')'
            }
            if (  $cond->isa( 'Perlito5::AST::Apply' ) 
               && (  $cond->code eq 'infix:<||>'
                  || $cond->code eq 'infix:<or>'
                  )
               ) 
            {
                return '(' . to_bool($cond->{arguments}->[0], $level) . ' || '
                           . to_bool($cond->{arguments}->[1], $level) . ')'
            }

            if  (  ($cond->isa( 'Perlito5::AST::Int' ))
                || ($cond->isa( 'Perlito5::AST::Num' ))
                || ($cond->isa( 'Perlito5::AST::Apply' ) && exists $op_to_bool{ $cond->code })
                )
            {
                return $cond->emit_javascript2($level, $wantarray);
            }
            else {
                return 'p5bool(' . $cond->emit_javascript2($level, $wantarray) . ')';
            }
    }

    sub is_scalar {
            !$_[0]->isa( 'Perlito5::AST::Int' )
         && !$_[0]->isa( 'Perlito5::AST::Num' )
         && !$_[0]->isa( 'Perlito5::AST::Buf' )
         && !$_[0]->isa( 'Perlito5::AST::Sub' )
         && !($_[0]->isa( 'Perlito5::AST::Var' ) && $_[0]->{sigil} eq '$')
         && !($_[0]->isa( 'Perlito5::AST::Apply' ) 
             && (  exists($op_to_str{ $_[0]->{code} })
                || exists($op_to_num{ $_[0]->{code} })
                || exists($op_to_bool{ $_[0]->{code} })
                #  || $_[0]->{code} eq 'prefix:<\\>'    -- \(@a) is a list
                )
             )
    }

    sub to_list {
        my $items = to_list_preprocess( $_[0] );
        my $level = $_[1];
        my $literal_type = $_[2] || 'array';    # 'array', 'hash'

        my $wantarray = 'list';

        my $interpolate = 0;
        for (@$items) {
            $interpolate = 1
                if is_scalar($_);
        }

        if ($literal_type eq 'hash') {
            if (!$interpolate) {
                # { x : y, ... }

                my @out;
                my $printable = 1;
                my @in = @$items;
                while (@in) {
                    my $k = shift @in;
                    my $v = shift @in;
                    $k = $k->emit_javascript2($level, 0);

                    $printable = 0
                        if $k =~ /[ \[]/;

                    $v = $v
                         ? $v->emit_javascript2($level, 0)
                         : 'null';
                    push @out, "$k : $v";
                }

                return '{' . join(', ', @out) . '}'
                    if $printable;

            }
            return 'p5a_to_h(' . to_list($items, $level, 'array') . ')';
        }

        $interpolate
        ? ( 'p5list_to_a(['
          .   join(', ', map( $_->emit_javascript2($level, $wantarray), @$items ))
          . '])'
          )
        : ( '['
          .   join(', ', map( $_->emit_javascript2($level, $wantarray), @$items ))
          . ']'
          )
    }

    sub to_list_preprocess {
        my @items;
        for my $item ( @{$_[0]} ) {
            if (  $item->isa( 'Perlito5::AST::Apply' ) 
               && ( $item->code eq 'circumfix:<( )>' || $item->code eq 'list:<,>' || $item->code eq 'infix:<=>>' )
               )
            {
                if ($item->isa('Perlito5::AST::Apply')
                   && $item->code eq 'infix:<=>>'
                   )
                {
                    $item->{arguments}[0] = Perlito5::AST::Lookup->autoquote( $item->{arguments}[0] );
                }

                for my $arg ( @{ to_list_preprocess($item->arguments) } ) {
                    push( @items, $arg);
                }
            }
            else {
                push( @items, $item);
            }
        }
        return \@items;
    }

    sub to_scalar {
        my $items = to_scalar_preprocess( $_[0] );
        my $level = $_[1];
        my $wantarray = 'scalar';

        # Note: v = 1,2,5  // 5

        @$items
        ?   '('
          .   join(', ', map( $_->emit_javascript2($level, $wantarray), @$items ))
          . ')'
        : 'null'
    }

    sub to_scalar_preprocess {
        my @items;
        for my $item ( @{$_[0]} ) {
            if (  $item->isa( 'Perlito5::AST::Apply' ) 
               && ( $item->code eq 'list:<,>' || $item->code eq 'infix:<=>>' )
               )
            {
                if ($item->isa('Perlito5::AST::Apply')
                   && $item->code eq 'infix:<=>>'
                   )
                {
                    $item->{arguments}[0] = Perlito5::AST::Lookup->autoquote( $item->{arguments}[0] );
                }

                for my $arg ( @{ to_scalar_preprocess($item->arguments) } ) {
                    push( @items, $arg);
                }
            }
            else {
                push( @items, $item);
            }
        }
        return \@items;
    }

    sub to_runtime_context {
        my $items = to_scalar_preprocess( $_[0] );
        my $level = $_[1];
        my $wantarray = 'runtime';

        return $items->[0]->emit_javascript2($level, $wantarray)
            if @$items == 1 && is_scalar($items->[0]);

        'p5context(' 
            . '['
            .   join(', ', map( $_->emit_javascript2($level, $wantarray), @$items ))
            . ']'
            . ', p5want)'
    }

    sub to_context {
        my $wantarray = shift;
         $wantarray eq 'list'   ? '1' 
        :$wantarray eq 'scalar' ? '0' 
        :$wantarray eq 'void'   ? 'null'
        :                         'p5want'
    }

    sub autoquote {
        my $index = shift;
        my $level = shift;
    
        # ok   ' sub x () { 123 } $v{x()} = 12; use Data::Dumper; print Dumper \%v '       # '123'     => 12
        # ok   ' sub x () { 123 } $v{x} = 12; use Data::Dumper; print Dumper \%v '         # 'x'       => 12
        # TODO ' sub x () { 123 } $v{main::x} = 12; use Data::Dumper; print Dumper \%v '   # '123'     => 12
        # ok   ' $v{main::x} = 12; use Data::Dumper; print Dumper \%v '                    # 'main::x' => 12
    
        $index = Perlito5::AST::Lookup->autoquote($index);
    
        return to_str($index, $level);
    }

    sub emit_javascript2_autovivify {
        my $obj = shift;
        my $level = shift;
        my $type = shift;  # 'array'/'hash'

        if (  $obj->isa( 'Perlito5::AST::Index' )
           || $obj->isa( 'Perlito5::AST::Lookup' )
           || $obj->isa( 'Perlito5::AST::Call' )
           )
        {
            return $obj->emit_javascript2($level, 0, $type);
        }

        if ( $obj->isa( 'Perlito5::AST::Apply' ) && $obj->code eq 'prefix:<$>' ) {
            my $arg  = $obj->{arguments}->[0];
            return 'p5scalar_deref(' 
                    . $arg->emit_javascript2( $level ) . ', '
                    . Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME) . ', '
                    . Perlito5::Javascript2::escape_string($type)      # autovivification type
                    . ')';
        }
        if ( $obj->isa( 'Perlito5::AST::Apply' ) ) {
            return $obj->emit_javascript2($level);
        }
        if ( $obj->isa( 'Perlito5::AST::Buf' ) ) {
            return $obj->emit_javascript2($level);
        }

        # TODO - Perlito5::AST::Var

          '(' .  $obj->emit_javascript2($level)
        .   ' || (' . $obj->emit_javascript2($level) . ' = ' 
                    . ( $type eq 'array' ? 'new p5ArrayRef([])' 
                      : $type eq 'hash'  ? 'new p5HashRef({})'
                      :                    'new p5ScalarRef(null)'
                      )
              . ')'
        . ')'
    }

    sub emit_javascript2_list_with_tabs {
        my ($level, $argument) = @_;
        my $tab = Perlito5::Javascript2::tab($level);
        return map { ref($_) eq 'ARRAY'
                     ? emit_javascript2_list_with_tabs($level+1, $_)
                     : $tab . $_
                   }
                   @$argument;
    }

    sub emit_func_javascript2 {
        my ($level, $wantarray, @argument) = @_;
        return join("\n", "function () {",
                          emit_javascript2_list_with_tabs($level, [
                                \@argument, "}"
                          ]));
    }

    sub emit_wrap_javascript2 {
        my ($level, $wantarray, @argument) = @_;
        return join("\n", "(function () {",
                          emit_javascript2_list_with_tabs($level, [
                                \@argument, "})()"
                          ]));
    }

    sub emit_function_javascript2 {
        my ($level, $wantarray, $argument) = @_;
        if (  $argument->isa( 'Perlito5::AST::Apply' )
           && (  $argument->code eq 'return'
              || $argument->code eq 'last'
              || $argument->code eq 'next'
              || $argument->code eq 'redo' ) )
        {
            emit_func_javascript2( $level, $wantarray,
                $argument->emit_javascript2($level, $wantarray)
            );
        }
        else {
            emit_func_javascript2( $level, $wantarray,
                'return ' . $argument->emit_javascript2($level+1, $wantarray)
            );
        }
    }

    sub emit_wrap_statement_javascript2 {
        my ($level, $wantarray, $argument) = @_;
        if ($wantarray eq 'void') {
            return $argument;
        }
        emit_wrap_javascript2( $level, $wantarray, $argument )
    }

}

package Perlito5::Javascript2::LexicalBlock;
{
    sub new { my $class = shift; bless {@_}, $class }
    sub block { $_[0]->{block} }
    # top_level - true if this is the main block in a subroutine;
    # create_context - ... 

    sub has_decl {
        my $self = $_[0];
        my $type = $_[1];
        for my $decl ( @{$self->{block}} ) {
            return 1
                if grep { $_->{decl} eq $type } $decl->emit_javascript2_get_decl();
        }
        return 0;
    }

    sub emit_javascript2_subroutine_body {
        my ($self, $level, $wantarray) = @_;
        $self->{top_level} = 1;
        my $outer_throw = $Perlito5::THROW;
        $Perlito5::THROW = 0;
        my $s = $self->emit_javascript2($level, $wantarray);
        $Perlito5::THROW    = $outer_throw;
        return $s;
    }

    sub emit_javascript2 {
        my ($self, $level, $wantarray) = @_;
        my $original_level = $level;

        my @block;
        for my $stmt (@{$self->{block}}) {
            if (defined($stmt)) {
                push @block, $stmt;
            }
        }
        if (!@block) {
            return 'return []'      if $wantarray eq 'list';
            return 'return null'    if $wantarray eq 'scalar';
            return 'return p5want ? [] : null' if $wantarray eq 'runtime';
            return 'null;';         # void
        }
        my @str;
        my $has_local = $self->has_decl("local");
        my $has_regex = 0;
        if (grep {$_->emit_javascript2_has_regex()} @block) {
            # regex variables like '$1' are implicitly 'local'
            $has_local = 1;
            $has_regex = 1;
        }
        my $create_context = $self->{create_context} && $self->has_decl("my");
        my $outer_pkg   = $Perlito5::PKG_NAME;

        if ($self->{top_level} || $create_context) {
            $level++;
        }

        my $last_statement;
        if ($wantarray ne 'void') {
            $last_statement = pop @block;
        }
        for my $decl ( @block ) {
            if ( ref($decl) eq 'Perlito5::AST::Apply' && $decl->code eq 'package' ) {
                $Perlito5::PKG_NAME = $decl->{namespace};
            }

            my @var_decl = $decl->emit_javascript2_get_decl();
            for my $arg (@var_decl) {
                # TODO - create a new context for the redeclared variable
                push @str, $arg->emit_javascript2_init($level, $wantarray);
            }

            if (!( $decl->isa( 'Perlito5::AST::Decl' ) && $decl->decl eq 'my' )) {
                push @str, $decl->emit_javascript2($level, 'void') . ';';
            }
        }

        if ($last_statement) {

            my @var_decl = $last_statement->emit_javascript2_get_decl();
            for my $arg (@var_decl) {
                # TODO - create a new context for the redeclared variable
                push @str, $arg->emit_javascript2_init($level, $wantarray);
            }

            if  (  $last_statement->isa( 'Perlito5::AST::Apply' ) 
                && $last_statement->code eq 'return'
                && $self->{top_level}
                && @{ $last_statement->{arguments} }
                ) 
            {
                $last_statement = $last_statement->{arguments}[0];
            }

            if    (  $last_statement->isa( 'Perlito5::AST::For' )
                  || $last_statement->isa( 'Perlito5::AST::While' )
                  || $last_statement->isa( 'Perlito5::AST::If' )
                  || $last_statement->isa( 'Perlito5::AST::Block' )
                  || $last_statement->isa( 'Perlito5::AST::Use' )
                  || $last_statement->isa( 'Perlito5::AST::Apply' ) && $last_statement->code eq 'goto'
                  || $last_statement->isa( 'Perlito5::AST::Apply' ) && $last_statement->code eq 'return'
                  )
            {
                push @str, $last_statement->emit_javascript2($level, $wantarray);
            }
            else {
                if ( $has_local ) {
                    push @str, 'return p5cleanup_local(local_idx, ('
                        . ( $wantarray eq 'runtime'
                          ? Perlito5::Javascript2::to_runtime_context([$last_statement], $level+1)
                          : $wantarray eq 'scalar'
                          ? Perlito5::Javascript2::to_scalar([$last_statement], $level+1)
                          : $last_statement->emit_javascript2($level, $wantarray)
                          )
                    . '));';
                }
                else {
                    push @str, 'return ('
                        . ( $wantarray eq 'runtime'
                          ? Perlito5::Javascript2::to_runtime_context([$last_statement], $level+1)
                          : $wantarray eq 'scalar'
                          ? Perlito5::Javascript2::to_scalar([$last_statement], $level+1)
                          : $last_statement->emit_javascript2($level, $wantarray)
                          )
                    . ');';
                }
            }
        }
        if ( $has_local ) {
            unshift @str, (
                    'var local_idx = p5LOCAL.length;',
                    ( $has_regex
                      ? ( 'var regex_tmp = p5_regex_capture;',
                          'p5LOCAL.push(function(){ p5_regex_capture = regex_tmp });',
                      )
                      : ()
                    )
                );
            push    @str, 'p5cleanup_local(local_idx, null);';
        }
        my $out;
        if ($self->{top_level} && $Perlito5::THROW) {

            # TODO - emit error message if catched a "next/redo/last LABEL" when expecting a "return" exception

            $level = $original_level;
            my $tab = "\n" . Perlito5::Javascript2::tab($level + 1);
            $out =                                         "try {"
                . $tab                                   .    join($tab, @str) . "\n"
                . Perlito5::Javascript2::tab($level)     . '}' . "\n"
                . Perlito5::Javascript2::tab($level)     . 'catch(err) {' . "\n"
                . Perlito5::Javascript2::tab($level + 1) .    'if ( err instanceof Error ) {' . "\n"
                . Perlito5::Javascript2::tab($level + 2)         . 'throw(err);' . "\n"
                . Perlito5::Javascript2::tab($level + 1) .    '}' . "\n"
                . Perlito5::Javascript2::tab($level + 1) .    'else {' . "\n"
                . Perlito5::Javascript2::tab($level + 2)
                    . ( $has_local
                      ? 'return p5cleanup_local(local_idx, err)'
                      : 'return(err)'
                      )
                    . ";\n"
                . Perlito5::Javascript2::tab($level + 1) .   '}' . "\n"
                . Perlito5::Javascript2::tab($level)     . '}';
        }
        elsif ( $create_context ) {
            $level = $original_level;
            my $tab = "\n" . Perlito5::Javascript2::tab($level + 1);
            $out =                                        "(function () {"
                  . $tab                               .     join($tab, @str) . "\n"
                  . Perlito5::Javascript2::tab($level) .  "})();";
        }
        else {
            $level = $original_level;
            my $tab = "\n" . Perlito5::Javascript2::tab($level);
            $out = join($tab, @str);
        }
        $Perlito5::PKG_NAME = $outer_pkg;
        return $out;
    }
    sub emit_javascript2_has_regex { () }
}

package Perlito5::AST::CompUnit;
{
    sub emit_javascript2 {
        my ($self, $level, $wantarray) = @_;
        return Perlito5::Javascript2::emit_wrap_javascript2($level, $wantarray, 
            Perlito5::Javascript2::LexicalBlock->new( block => $self->{body} )->emit_javascript2( $level + 1, $wantarray )
        );
    }
    sub emit_javascript2_program {
        my ($comp_units, %options) = @_;
        $Perlito5::PKG_NAME = 'main';
        my $level = 0;
        my $wantarray = 'void';
        my $str;
        $str .= Perlito5::Compiler::do_not_edit("//");
        if ( $options{expand_use} ) {
            $str .= Perlito5::Javascript2::Runtime->emit_javascript2();
            $str .= Perlito5::Javascript2::Array->emit_javascript2();
            $str .= Perlito5::Javascript2::CORE->emit_javascript2();
            $str .= Perlito5::Javascript2::IO->emit_javascript2();
            $str .= Perlito5::Javascript2::Sprintf->emit_javascript2();
        }
        $str .= "var p5want;\n"
             .  "var List__ = [];\n";
        for my $comp_unit ( @$comp_units ) {
            $str = $str . $comp_unit->emit_javascript2($level, $wantarray) . "\n";
        }
        return $str;
    }
    sub emit_javascript2_get_decl { () }
    sub emit_javascript2_has_regex { () }
}

package Perlito5::AST::Int;
{
    sub emit_javascript2 {
        my ($self, $level, $wantarray) = @_;
        $self->{int};
    }
    sub emit_javascript2_get_decl { () }
    sub emit_javascript2_has_regex { () }
}

package Perlito5::AST::Num;
{
    sub emit_javascript2 {
        my ($self, $level, $wantarray) = @_;
        $self->{num};
    }
    sub emit_javascript2_get_decl { () }
    sub emit_javascript2_has_regex { () }
}

package Perlito5::AST::Buf;
{
    sub emit_javascript2 {
        my ($self, $level, $wantarray) = @_;
        Perlito5::Javascript2::escape_string( $self->{buf} );
    }
    sub emit_javascript2_get_decl { () }
    sub emit_javascript2_has_regex { () }
}

package Perlito5::AST::Block;
{
    sub emit_javascript2 {
        my ($self, $level, $wantarray) = @_;
        my $body;
        if ($wantarray ne 'void') {
            $body = Perlito5::Javascript2::LexicalBlock->new( block => $self->{stmts} );
        }
        else {
            $body = Perlito5::Javascript2::LexicalBlock->new( block => $self->{stmts} );
        }

        my $init = "";
        if ($self->{name} eq 'INIT') {
            my $tmp  = 'p5pkg.main.' . Perlito5::Javascript2::get_label();

            # INIT-blocks execute only once
            $init = Perlito5::Javascript2::tab($level + 2) . "if ($tmp) { return }; $tmp = 1;\n";

            # TODO - make this execute before anything else

        }

        return 
                  ( $wantarray ne 'void'
                  ? "return "
                  : ""
                  )
                . 'p5block('
                . "function (v) {}, "
                . "function () {\n"
                .                                             $init
                . Perlito5::Javascript2::tab($level + 2) .    $body->emit_javascript2($level + 2, $wantarray) . "\n"
                . Perlito5::Javascript2::tab($level + 1) . '}, '
                .   '[0], '
                . $self->emit_javascript2_continue($level, $wantarray) . ', '
                . Perlito5::Javascript2::escape_string($self->{label} || "") . "\n"
                . Perlito5::Javascript2::tab($level) . ')'
    }
    sub emit_javascript2_continue {
        my $self = shift;
        my $level = shift;
        my $wantarray = shift;

        if (!$self->{continue} || !@{ $self->{continue}{stmts} }) {
            return 'false'
        }

        return
              "function () {\n"
            .   (Perlito5::Javascript2::LexicalBlock->new( block => $self->{continue}->stmts ))->emit_javascript2($level + 2, $wantarray) . "\n"
            . Perlito5::Javascript2::tab($level + 1) . '}'
    }
    sub emit_javascript2_get_decl { () }
    sub emit_javascript2_has_regex { () }
}

package Perlito5::AST::Index;
{
    sub emit_javascript2 {
        my ($self, $level, $wantarray, $autovivification_type) = @_;
        # autovivification_type: array, hash
        my $method = $autovivification_type || 'p5aget';
        $method = 'p5aget_array' if $autovivification_type eq 'array';
        $method = 'p5aget_hash'  if $autovivification_type eq 'hash';
        if (  (  $self->{obj}->isa('Perlito5::AST::Apply')
              && $self->{obj}->{code} eq 'prefix:<@>'
              )
           || (  $self->{obj}->isa('Perlito5::AST::Var')
              && $self->{obj}->sigil eq '@'
              )
           || (  $self->{obj}->isa('Perlito5::AST::Apply')
              && $self->{obj}->code eq 'circumfix:<( )>'
              )
           )
        {
            # @a[10, 20]
            # @$a[0, 2] ==> @{$a}[0,2]
            # (4,5,6)[0,2]
            return 'p5list_slice('
                        . $self->{obj}->emit_javascript2($level, 'list') . ', '
                        . Perlito5::Javascript2::to_list([$self->{index_exp}], $level) . ', '
                        . Perlito5::Javascript2::to_context($wantarray)
                   . ')'
        }
        if (  (  $self->{obj}->isa('Perlito5::AST::Apply')
              && $self->{obj}->{code} eq 'prefix:<%>'
              )
           || (  $self->{obj}->isa('Perlito5::AST::Var')
              && $self->{obj}->sigil eq '%'
              )
           )
        {
            # Perl5.20 hash slice
            # %a[10, 20]
            # %$a[0, 2] ==> %{$a}[0,2]

            # "fix" the sigil type
            my $obj = $self->{obj};
            $obj->{sigil} = '@'
                if $obj->{sigil} eq '%';
            $obj->{code} = 'prefix:<@>'
                if $obj->{code} eq 'prefix:<%>';

            return 'p5hash_slice('
                        . $self->{obj}->emit_javascript2($level, 'list') . ', '
                        . Perlito5::Javascript2::to_list([$self->{index_exp}], $level) . ', '
                        . Perlito5::Javascript2::to_context($wantarray)
                   . ')';
        }
        return $self->emit_javascript2_container($level) . '.' . $method . '(' 
                        . Perlito5::Javascript2::to_num($self->{index_exp}, $level) 
                    . ')';
    }
    sub emit_javascript2_set {
        my ($self, $arguments, $level, $wantarray) = @_;
        if (  (  $self->{obj}->isa('Perlito5::AST::Apply')
              && $self->{obj}->{code} eq 'prefix:<@>'
              )
           || (  $self->{obj}->isa('Perlito5::AST::Var')
              && $self->{obj}->sigil eq '@'
              )
           )
        {
            # @a[10, 20]
            # @$a[0, 2] ==> @{$a}[0,2]
            return Perlito5::Javascript2::emit_wrap_javascript2($level, $wantarray, 
                    'var a = [];',
                    'var v = ' . Perlito5::Javascript2::to_list([$self->{index_exp}], $level) . ';',
                    'var src=' . Perlito5::Javascript2::to_list([$arguments], $level) . ";",
                    'var out=' . Perlito5::Javascript2::emit_javascript2_autovivify( $self->{obj}, $level, 'array' ) . ";",
                    'var tmp' . ";",
                    'for (var i=0, l=v.length; i<l; ++i) {',
                          [ 'tmp = src.p5aget(i);',
                            'out.p5aset(v[i], tmp);',
                            'a.push(tmp)',
                          ],
                    '}',
                    'return a',
            )
        }
        return $self->emit_javascript2_container($level) . '.p5aset(' 
                    . Perlito5::Javascript2::to_num($self->{index_exp}, $level+1) . ', ' 
                    . Perlito5::Javascript2::to_scalar([$arguments], $level+1)
                . ')';
    }
    sub emit_javascript2_set_list {
        my ($self, $level, $list) = @_;
        my $wantarray = 'list';
        if (  (  $self->{obj}->isa('Perlito5::AST::Apply')
              && $self->{obj}->{code} eq 'prefix:<@>'
              )
           || (  $self->{obj}->isa('Perlito5::AST::Var')
              && $self->{obj}->sigil eq '@'
              )
           )
        {
            # @a[10, 20]
            # @$a[0, 2] ==> @{$a}[0,2]
            return Perlito5::Javascript2::emit_wrap_javascript2($level, $wantarray, 
                    'var a = [];',
                    'var v = ' . Perlito5::Javascript2::to_list([$self->{index_exp}], $level) . ';',
                    'var out=' . Perlito5::Javascript2::emit_javascript2_autovivify( $self->{obj}, $level, 'array' ) . ";",
                    'var tmp' . ";",
                    'for (var i=0, l=v.length; i<l; ++i) {',
                          [ 'tmp = ' . $list . '.shift();',
                            'out.p5aset(v[i], tmp);',
                            'a.push(tmp)',
                          ],
                    '}',
                    'return a',
            )
        }
        return $self->emit_javascript2_container($level) . '.p5aset(' 
                    . Perlito5::Javascript2::to_num($self->{index_exp}, $level+1) . ', ' 
                    . $list . '.shift()'
                . ')';
    }
    sub emit_javascript2_container {
        my $self = shift;
        my $level = shift;
        if (  $self->{obj}->isa('Perlito5::AST::Apply')
           && $self->{obj}->{code} eq 'prefix:<$>'
           )
        {
            # ${"Exporter::Cache"}[2]
            # $$a[0] ==> $a->[0]
            my $v = Perlito5::AST::Apply->new( %{$self->{obj}}, code => 'prefix:<@>' );
            return $v->emit_javascript2($level);
        }
        if (  $self->{obj}->isa('Perlito5::AST::Apply')
           && $self->{obj}->code eq 'circumfix:<( )>'
           )
        {
            # the expression inside () returns a list
            return Perlito5::Javascript2::to_list([$self->{obj}], $level);
        }
        if (  $self->{obj}->isa('Perlito5::AST::Var')
           && $self->{obj}->sigil eq '$'
           )
        {
            $self->{obj}->{sigil} = '@';
            return $self->{obj}->emit_javascript2($level);
        }
        else {
            return Perlito5::Javascript2::emit_javascript2_autovivify( $self->{obj}, $level, 'array' ) . '._array_';
        }
    }
    sub emit_javascript2_get_decl { () }
    sub emit_javascript2_has_regex { () }
}

package Perlito5::AST::Lookup;
{
    sub emit_javascript2 {
        my ($self, $level, $wantarray, $autovivification_type) = @_;
        # autovivification_type: array, hash
        my $method = $autovivification_type || 'p5hget';
        $method = 'p5hget_array' if $autovivification_type eq 'array';
        $method = 'p5hget_hash'  if $autovivification_type eq 'hash';
        if (  (  $self->{obj}->isa('Perlito5::AST::Apply')
              && $self->{obj}->{code} eq 'prefix:<@>'
              )
           || (  $self->{obj}->isa('Perlito5::AST::Var')
              && $self->{obj}->sigil eq '@'
              )
           )
        {
            # @a{ 'x', 'y' }
            # @$a{ 'x', 'y' }  ==> @{$a}{ 'x', 'y' }
            my $v;
            if ( $self->{obj}->isa('Perlito5::AST::Var') ) {
                $v = $self->{obj};
            }
            $v = Perlito5::AST::Apply->new( code => 'prefix:<%>', namespace => $self->{obj}->namespace, arguments => $self->{obj}->arguments )
                if $self->{obj}->isa('Perlito5::AST::Apply');

            return 'p5list_lookup_slice('
                        . $v->emit_javascript2($level, 'list') . ', '
                        . Perlito5::Javascript2::to_list([$self->{index_exp}], $level) . ', '
                        . Perlito5::Javascript2::to_context($wantarray)
                   . ')'
        }
        if (  (  $self->{obj}->isa('Perlito5::AST::Apply')
              && $self->{obj}->{code} eq 'prefix:<%>'
              )
           || (  $self->{obj}->isa('Perlito5::AST::Var')
              && $self->{obj}->sigil eq '%'
              )
           )
        {
            # Perl5.20 hash slice
            # %a{ 'x', 'y' }
            # %$a{ 'x', 'y' }  ==> %{$a}{ 'x', 'y' }
            my $v;
            if ( $self->{obj}->isa('Perlito5::AST::Var') ) {
                $v = $self->{obj};
            }
            $v = Perlito5::AST::Apply->new( code => 'prefix:<%>', namespace => $self->{obj}->namespace, arguments => $self->{obj}->arguments )
                if $self->{obj}->isa('Perlito5::AST::Apply');

            return 'p5hash_lookup_slice('
                        . $v->emit_javascript2($level, 'list') . ', '
                        . Perlito5::Javascript2::to_list([$self->{index_exp}], $level) . ', '
                        . Perlito5::Javascript2::to_context($wantarray)
                   . ')'
        }
        return $self->emit_javascript2_container($level) . '.' . $method . '('
                . Perlito5::Javascript2::autoquote($self->{index_exp}, $level)
            . ')';
    }
    sub emit_javascript2_set {
        my ($self, $arguments, $level, $wantarray) = @_;
        if (  (  $self->{obj}->isa('Perlito5::AST::Apply')
              && $self->{obj}->{code} eq 'prefix:<@>'
              )
           || (  $self->{obj}->isa('Perlito5::AST::Var')
              && $self->{obj}->sigil eq '@'
              )
           )
        {
            # @a{ 'x', 'y' }
            # @$a{ 'x', 'y' }  ==> @{$a}{ 'x', 'y' }
            my $v;
            $v = $self->{obj}
                if $self->{obj}->isa('Perlito5::AST::Var');
            $v = Perlito5::AST::Apply->new( code => 'prefix:<%>', namespace => $self->{obj}->namespace, arguments => $self->{obj}->arguments )
                if $self->{obj}->isa('Perlito5::AST::Apply');
            return Perlito5::Javascript2::emit_wrap_javascript2($level, $wantarray, 
                    'var a = [];',
                    'var v = ' . Perlito5::Javascript2::to_list([$self->{index_exp}], $level) . ';',
                    'var src=' . Perlito5::Javascript2::to_list([$arguments], $level) . ";",
                    'var out=' . $v->emit_javascript2($level) . ";",
                    'var tmp' . ";",
                    'for (var i=0, l=v.length; i<l; ++i)' . '{',
                          [ 'tmp = src.p5hget(i);',
                            'out.p5hset(v[i], tmp);',
                            'a.push(tmp)',
                          ],
                    '}',
                    'return a',
            )
        }
        return $self->emit_javascript2_container($level) . '.p5hset('
                    . Perlito5::Javascript2::autoquote($self->{index_exp}, $level) . ', '
                    . Perlito5::Javascript2::to_scalar([$arguments], $level+1)
            . ')';
    }
    sub emit_javascript2_set_list {
        my ($self, $level, $list) = @_;
        my $wantarray = 'list';
        if (  (  $self->{obj}->isa('Perlito5::AST::Apply')
              && $self->{obj}->{code} eq 'prefix:<@>'
              )
           || (  $self->{obj}->isa('Perlito5::AST::Var')
              && $self->{obj}->sigil eq '@'
              )
           )
        {
            # @a{ 'x', 'y' }
            # @$a{ 'x', 'y' }  ==> @{$a}{ 'x', 'y' }
            my $v;
            $v = $self->{obj}
                if $self->{obj}->isa('Perlito5::AST::Var');
            $v = Perlito5::AST::Apply->new( code => 'prefix:<%>', namespace => $self->{obj}->namespace, arguments => $self->{obj}->arguments )
                if $self->{obj}->isa('Perlito5::AST::Apply');
            return Perlito5::Javascript2::emit_wrap_javascript2($level, $wantarray, 
                    'var a = [];',
                    'var v = ' . Perlito5::Javascript2::to_list([$self->{index_exp}], $level) . ';',
                    'var out=' . $v->emit_javascript2($level) . ";",
                    'var tmp' . ";",
                    'for (var i=0, l=v.length; i<l; ++i)' . '{',
                          [ 'tmp = ' . $list . '.shift();',
                            'out.p5hset(v[i], tmp);',
                            'a.push(tmp)',
                          ],
                    '}',
                    'return a',
            )
        }
        return $self->emit_javascript2_container($level) . '.p5hset('
                    . Perlito5::Javascript2::autoquote($self->{index_exp}, $level) . ', '
                    . $list . '.shift()'
            . ')';
    }
    sub emit_javascript2_container {
        my $self = shift;
        my $level = shift;
        if (  $self->{obj}->isa('Perlito5::AST::Apply')
           && $self->{obj}->{code} eq 'prefix:<$>'
           )
        {
            # ${"Exporter::Cache"}{x}
            # $$a{0} ==> $a->{0}
            my $v = Perlito5::AST::Apply->new( %{$self->{obj}}, code => 'prefix:<%>' );
            return $v->emit_javascript2($level);
        }
        if (  $self->{obj}->isa('Perlito5::AST::Var')
           && $self->{obj}->sigil eq '$'
           )
        {
            # my $v = $self->{obj};   HERE

            #if ($self->{obj}{_real_sigil} ne '%') {
            #    warn Data::Dumper::Dumper($self->{obj});
            #}

            my $v = Perlito5::AST::Var->new( %{$self->{obj}}, sigil => '%' );
            return $v->emit_javascript2($level)
        }
        else {
            return Perlito5::Javascript2::emit_javascript2_autovivify( $self->{obj}, $level, 'hash' ) . '._hash_';
        }
    }
    sub emit_javascript2_get_decl { () }
    sub emit_javascript2_has_regex { () }
}

package Perlito5::AST::Var;
{
    my $table = {
        '$' => 'v_',
        '@' => 'List_',
        '%' => 'Hash_',
        '&' => '',
    };

    sub emit_javascript2_global {
        my ($self, $level, $wantarray) = @_;
        my $str_name = $self->{name};
        my $sigil = $self->{_real_sigil} || $self->{sigil};
        my $namespace = $self->{namespace} || $self->{_namespace};
        if ($sigil eq '@' && $self->{name} eq '_' && $namespace eq 'main') {
            # XXX - optimization - @_ is a js lexical
            my $s = 'List__';
            if ($self->{sigil} eq '$#') {
                return '(' . $s . '.length - 1)';
            }
            if ( $wantarray eq 'scalar' ) {
                return $s . '.length';
            }
            if ( $wantarray eq 'runtime' ) {
                return '(p5want'
                    . ' ? ' . $s
                    . ' : ' . $s . '.length'
                    . ')';
            }
            return $s;
        }

        if ($sigil eq '$' && $self->{name} > 0) {
            # regex captures
            return 'p5_regex_capture[' . ($self->{name} - 1) . ']'
        }
        if ( $sigil eq '::' ) {

            return Perlito5::Javascript2::pkg()
                if $self->{namespace} eq '__PACKAGE__';
            return $Perlito5::AST::Sub::SUB_REF // '__SUB__'
                if $self->{namespace} eq '__SUB__';

            return Perlito5::Javascript2::escape_string( $namespace );
        }

        my $s = 'p5make_package(' . Perlito5::Javascript2::escape_string($namespace ) . ')[' . Perlito5::Javascript2::escape_string($table->{$sigil} . $str_name) . ']';
        if ( $sigil eq '*' ) {
            return $s;
        }
        if ( $sigil eq '&' ) {
            return $s . '(List__, ' . Perlito5::Javascript2::to_context($wantarray) . ')';
        }
        if ($sigil eq '@') {
            $s = $s . ' || (' . $s . ' = [])';  # init
            $s = 'p5pkg[' . $s . ', ' . Perlito5::Javascript2::escape_string($namespace ) . '][' . Perlito5::Javascript2::escape_string($table->{$sigil} . $str_name) . ']';
            if ($self->{sigil} eq '$#') {
                return '(' . $s . '.length - 1)';
            }
            if ( $wantarray eq 'scalar' ) {
                return $s . '.length';
            }
        }
        elsif ($sigil eq '%') {
            $s = $s . ' || (' . $s . ' = {})';  # init
            $s = 'p5pkg[' . $s . ', ' . Perlito5::Javascript2::escape_string($namespace ) . '][' . Perlito5::Javascript2::escape_string($table->{$sigil} . $str_name) . ']';
        }
        return $s;
    }

    sub emit_javascript2 {
        my ($self, $level, $wantarray) = @_;
        my $sigil = $self->{_real_sigil} || $self->{sigil};
        my $str_name = $self->{name};
        my $decl_type = $self->{_decl} || 'global';
        if ( $decl_type ne 'my' ) {
            return $self->emit_javascript2_global($level, $wantarray);
        }
        if ( $sigil eq '@' ) {
            if ( $wantarray eq 'scalar' ) {
                return $self->emit_javascript2($level, 'list') . '.length';
            }
            if ( $wantarray eq 'runtime' ) {
                return '(p5want'
                    . ' ? ' . $self->emit_javascript2($level, 'list')
                    . ' : ' . $self->emit_javascript2($level, 'list') . '.length'
                    . ')';
            }
        }
        if ($self->{sigil} eq '$#') {
            return '(' . $table->{'@'} . $str_name . '.length - 1)';
        }
        $table->{$sigil} . $str_name
    }

    sub emit_javascript2_set {
        my ($self, $arguments, $level, $wantarray) = @_;
        my $open  = $wantarray eq 'void' ? '' : '(';
        my $close = $wantarray eq 'void' ? '' : ')';
        my $sigil = $self->{_real_sigil} || $self->{sigil};
        if ( $sigil eq '$' ) {
            return $open . $self->emit_javascript2() . ' = ' . Perlito5::Javascript2::to_scalar([$arguments], $level+1) . $close
        }
        if ( $sigil eq '@' ) {

            if ($self->{sigil} eq '$#') {
                $self->{sigil} = '@';
                return $open . $self->emit_javascript2() . '.length = 1 + ' . Perlito5::Javascript2::to_scalar([$arguments], $level+1) . $close
            }

            return $open . $self->emit_javascript2() . ' = ' . Perlito5::Javascript2::to_list([$arguments], $level+1) . $close
        }
        if ( $sigil eq '%' ) {
            return $open . $self->emit_javascript2() . ' = ' . Perlito5::Javascript2::to_list([$arguments], $level+1, 'hash') . $close 
        }
        if ( $sigil eq '*' ) {
            my $namespace = $self->{namespace} || $self->{_namespace};
            return 'p5typeglob_set(' 
            .   Perlito5::Javascript2::escape_string($namespace) . ', '
            .   Perlito5::Javascript2::escape_string($self->{name}) . ', ' 
            .   Perlito5::Javascript2::to_scalar([$arguments], $level+1)
            . ')'
        }
        die "don't know how to assign to variable ", $sigil, $self->name;
    }

    sub emit_javascript2_set_list {
        my ($self, $level, $list) = @_;
        my $sigil = $self->{_real_sigil} || $self->{sigil};
        if ( $sigil eq '$' ) {
            return $self->emit_javascript2() . ' = ' . $list  . '.shift()'
        }
        if ( $sigil eq '@' ) {
            return join( ";\n" . Perlito5::Javascript2::tab($level),
                $self->emit_javascript2() . ' = ' . $list,
                $list . ' = []'
            );
        }
        if ( $sigil eq '%' ) {
            return join( ";\n" . Perlito5::Javascript2::tab($level),
                $self->emit_javascript2() . ' = p5a_to_h(' . $list  . ')',
                $list . ' = []'
            );
        }
        die "don't know how to assign to variable ", $sigil, $self->name;
    }

    sub emit_javascript2_get_decl { () }
    sub emit_javascript2_has_regex { () }
}

package Perlito5::AST::Decl;
{
    sub emit_javascript2 {
        my ($self, $level, $wantarray) = @_;
        $self->{var}->emit_javascript2( $level );
    }
    sub emit_javascript2_init {
        my ($self, $level, $wantarray) = @_;
        if ($self->{decl} eq 'local') {
            my $var = $self->{var};
            my $var_set;
            my $tmp_name  = Perlito5::Javascript2::get_label();
            if ( ref($var) eq 'Perlito5::AST::Var' ) {
                $var_set = $var->emit_javascript2 . ' = v_' . $tmp_name;
            }
            else {
                my $tmp = Perlito5::AST::Var->new(sigil => '$', name => $tmp_name, _decl => 'my' );
                $var_set = $var->emit_javascript2_set($tmp);
            }
            return Perlito5::Javascript2::emit_wrap_javascript2($level, $wantarray, 
                     'var v_' . $tmp_name . ' = ' . $var->emit_javascript2 . ';',
                     'p5LOCAL.push(function(){ ' . $var_set . ' });',
                     'return ' . $var->emit_javascript2_set(
                                    Perlito5::AST::Apply->new( code => 'undef', arguments => [], namespace => '' ),
                                    $level+1
                                 ) . ';',
                ) . ';';
        }
        if ($self->{decl} eq 'my') {
            my $str = 'var ' . $self->{var}->emit_javascript2();
            if ($self->{var}->sigil eq '%') {
                $str = $str . ' = {};';
            }
            elsif ($self->{var}->sigil eq '@') {
                $str = $str . ' = [];';
            }
            else {
                $str = $str . ';';
            }
            return $str;
        }
        elsif ($self->{decl} eq 'our') {
            my $str = $self->{var}->emit_javascript2();
            if ($self->{var}->sigil eq '%') {
                $str = $str . ' = {};';
            }
            elsif ($self->{var}->sigil eq '@') {
                $str = $str . ' = [];';
            }
            else {
                return '// our ' . $str;
            }
            return 'if (typeof ' . $self->{var}->emit_javascript2() . ' == "undefined" ) { '
                    . $str
                    . '}';
        }
        elsif ($self->{decl} eq 'state') {
            # TODO
            return '// state ' . $self->{var}->emit_javascript2();
        }
        else {
            die "not implemented: Perlito5::AST::Decl '" . $self->{decl} . "'";
        }
    }
    sub emit_javascript2_set {
        my ($self, $arguments, $level, $wantarray) = @_;
        $self->var->emit_javascript2_set($arguments, $level, $wantarray);
    }
    sub emit_javascript2_set_list {
        my ($self, $level, $list) = @_;
        $self->var->emit_javascript2_set_list($level, $list);
    }
    sub emit_javascript2_get_decl {
        my $self = shift;
        return ($self);
    }
    sub emit_javascript2_has_regex { () }
}

package Perlito5::AST::Call;
{
    sub emit_javascript2 {
        my ($self, $level, $wantarray, $autovivification_type) = @_;
        # autovivification_type: array, hash
        my $meth = $self->{method};

        if ( $meth eq 'postcircumfix:<[ ]>' ) {
            my $method = $autovivification_type || 'p5aget';
            $method = 'p5aget_array' if $autovivification_type eq 'array';
            $method = 'p5aget_hash'  if $autovivification_type eq 'hash';
            return Perlito5::Javascript2::emit_javascript2_autovivify( $self->{invocant}, $level, 'array' )
                . '._array_.' . $method . '(' . Perlito5::Javascript2::to_num($self->{arguments}, $level+1)
                . ')';
        }
        if ( $meth eq 'postcircumfix:<{ }>' ) {
            my $method = $autovivification_type || 'p5hget';
            $method = 'p5hget_array' if $autovivification_type eq 'array';
            $method = 'p5hget_hash'  if $autovivification_type eq 'hash';
            return Perlito5::Javascript2::emit_javascript2_autovivify( $self->{invocant}, $level, 'hash' )
                . '._hash_.' . $method . '(' . Perlito5::Javascript2::autoquote($self->{arguments}, $level+1, 'list')
                . ')';
        }
        if  ($meth eq 'postcircumfix:<( )>')  {

            my $invocant;
            if (  ref( $self->{invocant} ) eq 'Perlito5::AST::Apply' 
               && $self->{invocant}{code} eq 'prefix:<&>'
               )
            {
                my $arg   = $self->{invocant}{arguments}->[0];
                $invocant = 'p5code_lookup_by_name(' . Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME ) . ', ' . $arg->emit_javascript2($level) . ')';
            }
            elsif (  ref( $self->{invocant} ) eq 'Perlito5::AST::Var' 
               && $self->{invocant}{sigil} eq '&'
               )
            {
                $invocant = 'p5pkg[' . Perlito5::Javascript2::escape_string(($self->{invocant}{namespace} || $Perlito5::PKG_NAME) ) . '][' . Perlito5::Javascript2::escape_string($self->{invocant}{name} ) . ']';
            }
            else {
                $invocant = $self->{invocant}->emit_javascript2($level, 'scalar');
            }

            return '(' . $invocant . ')(' . Perlito5::Javascript2::to_list($self->{arguments}) . ', '
                        . Perlito5::Javascript2::to_context($wantarray)
                    . ')';
        }

        my $invocant = $self->{invocant}->emit_javascript2($level, 'scalar');
        if ( ref($meth) eq 'Perlito5::AST::Var' ) {
            $meth = $meth->emit_javascript2($level, 'scalar');
        }
        else {
            $meth = Perlito5::Javascript2::escape_string($meth);
        }
        return 'p5call(' . $invocant . ', ' 
                         . $meth . ', ' 
                         . Perlito5::Javascript2::to_list($self->{arguments}) . ', '
                         . Perlito5::Javascript2::to_context($wantarray)
                  . ')'
    }

    sub emit_javascript2_set {
        my ($self, $arguments, $level, $wantarray) = @_;
        if ( $self->{method} eq 'postcircumfix:<[ ]>' ) {
            return Perlito5::Javascript2::emit_javascript2_autovivify( $self->{invocant}, $level, 'array' )
                    . '._array_.p5aset(' 
                        . Perlito5::Javascript2::to_num($self->{arguments}, $level+1) . ', ' 
                        . Perlito5::Javascript2::to_scalar([$arguments], $level+1)
                    . ')';
        }
        if ( $self->{method} eq 'postcircumfix:<{ }>' ) {
            return Perlito5::Javascript2::emit_javascript2_autovivify( $self->{invocant}, $level, 'hash' )
                    . '._hash_.p5hset(' 
                        . Perlito5::Javascript2::autoquote($self->{arguments}, $level+1, 'list') . ', '
                        . Perlito5::Javascript2::to_scalar([$arguments], $level+1)
                    . ')';
        }
        die "don't know how to assign to method ", $self->{method};
    }
    sub emit_javascript2_set_list {
        my ($self, $level, $list) = @_;
        if ( $self->{method} eq 'postcircumfix:<[ ]>' ) {
            return Perlito5::Javascript2::emit_javascript2_autovivify( $self->{invocant}, $level, 'array' )
                    . '._array_.p5aset(' 
                        . Perlito5::Javascript2::to_num($self->{arguments}, $level+1) . ', ' 
                        . $list  . '.shift()'
                    . ')';
        }
        if ( $self->{method} eq 'postcircumfix:<{ }>' ) {
            return Perlito5::Javascript2::emit_javascript2_autovivify( $self->{invocant}, $level, 'hash' )
                    . '._hash_.p5hset(' 
                        . Perlito5::Javascript2::autoquote($self->{arguments}, $level+1, 'list') . ', '
                        . $list  . '.shift()'
                    . ')';
        }
        die "don't know how to assign to method ", $self->{method};
    }
    sub emit_javascript2_get_decl { () }
    sub emit_javascript2_has_regex { () }
}

package Perlito5::AST::Apply;
{
    sub emit_regex_javascript2 {
        my $op = shift;
        my $var = shift;
        my $regex = shift;
        my $level     = shift;
        my $wantarray = shift;

        if ($regex->isa('Perlito5::AST::Var')) {
            # $x =~ $regex
            $regex = { code => 'p5:m', arguments => [ $regex, '' ] };
        }

        my $str;
        my $code = $regex->{code};
        my $regex_args = $regex->{arguments};
        if ($code eq 'p5:s') {
            my $replace = $regex_args->[1];
            my $modifier = $regex_args->[2]->{buf};
            my $fun;
            if (ref($replace) eq 'Perlito5::AST::Block') {
                $replace = Perlito5::AST::Sub->new(
                            block => $replace,
                        );
                $fun = $replace->emit_javascript2($level+2, $wantarray);
                $modifier =~ s/e//g;
            }
            else {
                $fun = Perlito5::Javascript2::emit_function_javascript2($level+2, $wantarray, $replace);
            }
            $str = Perlito5::Javascript2::emit_wrap_javascript2($level+1, $wantarray, 
                "var tmp = p5s("
                    . $var->emit_javascript2() . ', '
                    . $regex_args->[0]->emit_javascript2() . ', '
                    . $fun . ', '
                    . Perlito5::Javascript2::escape_string($modifier) . ', '
                    . ( $wantarray eq 'runtime' ? 'p5want' : $wantarray eq 'list' ? 1 : 0 )
                  . ");",
                $var->emit_javascript2() . " = tmp[0];",
                "return tmp[1];",
            );
        }
        elsif ($code eq 'p5:m') {
            $str = 'p5m('
                    . $var->emit_javascript2() . ', '
                    . $regex_args->[0]->emit_javascript2() . ', '
                    . Perlito5::Javascript2::escape_string($regex_args->[1]->{buf}) . ', '
                    . ( $wantarray eq 'runtime' ? 'p5want' : $wantarray eq 'list' ? 1 : 0 )
                  . ")";
        }
        elsif ($code eq 'p5:tr') {
            $str = Perlito5::Javascript2::emit_wrap_javascript2($level+1, $wantarray, 
                "var tmp = p5tr("
                    . $var->emit_javascript2() . ', '
                    . $regex_args->[0]->emit_javascript2() . ', '
                    . $regex_args->[1]->emit_javascript2() . ', '
                    . Perlito5::Javascript2::escape_string($regex_args->[2]->{buf}) . ', '
                    . ( $wantarray eq 'runtime' ? 'p5want' : $wantarray eq 'list' ? 1 : 0 )
                  . ");",
                $var->emit_javascript2() . " = tmp[0];",
                "return tmp[1];",
            );
        }
        else {
            die "Error: regex emitter - unknown operator $code";
        }

        if ($op eq '=~') {
            return $str;
        }
        if ($op eq '!~') {
            return '!(' . $str . ')'
        }
        die "Error: regex emitter";
    }

    sub emit_javascript2_set {
        my ($self, $arguments, $level, $wantarray) = @_;
        my $code = $self->{code};
        if ($code eq 'prefix:<$>') {
            return 'p5scalar_deref_set(' 
                . Perlito5::Javascript2::emit_javascript2_autovivify( $self->{arguments}->[0], $level+1, 'scalar' ) . ', '
                . Perlito5::Javascript2::to_scalar([$arguments], $level+1)  . ', '
                . Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME)
                . ')';
        }
        if ($code eq 'prefix:<*>') {
            return 'p5typeglob_deref_set(' 
                . Perlito5::Javascript2::to_scalar($self->{arguments}, $level+1) . ', '
                . Perlito5::Javascript2::to_scalar([$arguments], $level+1)       . ', '
                . Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME)
                . ')';
        }
        my $open  = $wantarray eq 'void' ? '' : '(';
        my $close = $wantarray eq 'void' ? '' : ')';
        $open . $self->emit_javascript2( $level+1 ) . ' = ' . $arguments->emit_javascript2( $level+1 ) . $close;
    }

    my %emit_js = (
        'infix:<=~>' => sub {
            my ($self, $level, $wantarray) = @_;
            emit_regex_javascript2( '=~', $self->{arguments}->[0], $self->{arguments}->[1], $level, $wantarray );
        },
        'infix:<!~>' => sub {
            my ($self, $level, $wantarray) = @_;
            emit_regex_javascript2( '!~', $self->{arguments}->[0], $self->{arguments}->[1], $level, $wantarray );
        },
        'p5:s' => sub {
            my ($self, $level, $wantarray) = @_;
            emit_regex_javascript2( '=~', $self->{arguments}->[3], $self, $level, $wantarray );
        },
        'p5:m' => sub {
            my ($self, $level, $wantarray) = @_;
            emit_regex_javascript2( '=~', $self->{arguments}->[2], $self, $level, $wantarray );
        },
        'p5:tr' => sub {
            my ($self, $level, $wantarray) = @_;
            emit_regex_javascript2( '=~', $self->{arguments}->[3], $self, $level, $wantarray );
        },
        'p5:qr' => sub {
            my ($self, $level, $wantarray) = @_;
            # p5qr( $str, $modifier );
            'p5qr(' . Perlito5::Javascript2::to_str( $self->{arguments}[0] ) . ', '
                    . Perlito5::Javascript2::to_str( $self->{arguments}[1] ) . ')';
        },
        '__PACKAGE__' => sub {
            my $self = $_[0];
            Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME);
        },
        '__SUB__' => sub {
            my $self = $_[0];
            $Perlito5::AST::Sub::SUB_REF // '__SUB__'
        },
        'wantarray' => sub {
            my $self = $_[0];
            'p5want';
        },
        'package' => sub {
            my $self = $_[0];
            'p5make_package(' . Perlito5::Javascript2::escape_string($self->{namespace} ) . ')';
        },
        'bless' => sub {
            my ($self, $level, $wantarray) = @_;
            my $class;
            if ($self->{arguments}[1]) {
                $class = Perlito5::Javascript2::to_str( $self->{arguments}[1] );
            }
            else { 
                $class = Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME);
            }
            'CORE.bless([' . $self->{arguments}[0]->emit_javascript2($level, 'scalar') . ', ' . $class . '])';
        },
        'infix:<~~>' => sub {
            my ($self, $level, $wantarray) = @_;
            my $arg0 = $self->{arguments}->[0];
            my $arg1 = $self->{arguments}->[1];
            # TODO - test argument type
            #   See: http://perldoc.perl.org/perlop.html#Smartmatch-Operator
            # if (Perlito5::Javascript2::is_num($arg1)) {
            #     # ==
            # }
            'p5smrt_scalar(' . $arg0->emit_javascript2($level, 'scalar') . ', '
                             . $arg1->emit_javascript2($level, 'scalar') . ')'
        },
        'infix:<&&>' => sub {
            my ($self, $level, $wantarray) = @_;
            'p5and('
                . $self->{arguments}->[0]->emit_javascript2($level, 'scalar') . ', '
                . Perlito5::Javascript2::emit_function_javascript2($level, $wantarray, $self->{arguments}->[1]) 
                . ')'
        },
        'infix:<and>' => sub {
            my ($self, $level, $wantarray) = @_;
            'p5and('
                . $self->{arguments}->[0]->emit_javascript2($level, 'scalar') . ', '
                . Perlito5::Javascript2::emit_function_javascript2($level, $wantarray, $self->{arguments}->[1]) 
                . ')'
        },
        'infix:<||>' => sub {
            my ($self, $level, $wantarray) = @_;
            'p5or('
                . $self->{arguments}->[0]->emit_javascript2($level, 'scalar') . ', '
                . Perlito5::Javascript2::emit_function_javascript2($level, $wantarray, $self->{arguments}->[1]) 
                . ')'
        },
        'infix:<or>' => sub {
            my ($self, $level, $wantarray) = @_;
            'p5or('
                . $self->{arguments}->[0]->emit_javascript2($level, 'scalar') . ', '
                . Perlito5::Javascript2::emit_function_javascript2($level, $wantarray, $self->{arguments}->[1]) 
                . ')'
        },
        'infix:<xor>' => sub {
            my ($self, $level, $wantarray) = @_;
            'p5xor('
                . $self->{arguments}->[0]->emit_javascript2($level, 'scalar') . ', '
                . Perlito5::Javascript2::emit_function_javascript2($level, $wantarray, $self->{arguments}->[1]) 
                . ')'
        },
        'infix:<=>>' => sub {
            my ($self, $level, $wantarray) = @_;
              Perlito5::AST::Lookup->autoquote($self->{arguments}[0])->emit_javascript2($level)  . ', ' 
            . $self->{arguments}[1]->emit_javascript2($level)
        },
        'infix:<cmp>' => sub {
            my $self = $_[0];
            'p5cmp(' . join( ', ', map( Perlito5::Javascript2::to_str($_), @{ $self->{arguments} } ) ) . ')';
        },
        'infix:<<=>>' => sub {
            my $self = $_[0];
            'p5cmp(' . join( ', ', map( Perlito5::Javascript2::to_num($_), @{ $self->{arguments} } ) ) . ')';
        },
        'infix:<**>' => sub {
            my $self = $_[0];
            'Math.pow(' . join( ', ', map( Perlito5::Javascript2::to_num($_), @{ $self->{arguments} } ) ) . ')';
        },
        'infix:<<<>' => sub {
            my $self = $_[0];
            'p5shift_left(' . join( ', ', map( Perlito5::Javascript2::to_num($_), @{ $self->{arguments} } ) ) . ')';
        },
        'infix:<%>' => sub {
            my $self = $_[0];
            'p5modulo(' . join( ', ', map( Perlito5::Javascript2::to_num($_), @{ $self->{arguments} } ) ) . ')';
        },
        'prefix:<!>' => sub {
            my $self      = shift;
            my $level     = shift;
            '!( ' . Perlito5::Javascript2::to_bool( $self->{arguments}->[0], $level ) . ')';
        },
        'prefix:<not>' => sub {
            my $self      = shift;
            my $level     = shift;
            my $arg = pop(@{$self->{arguments}});
            if (!$arg) {
                return 'true';
            }
            '!( ' . Perlito5::Javascript2::to_bool( $arg, $level ) . ')';
        },
        'prefix:<~>' => sub {
            my $self = $_[0];
            'p5complement( ' . Perlito5::Javascript2::to_num( $self->{arguments}->[0] ) . ')';
        },
        'prefix:<->' => sub {
            my ($self, $level, $wantarray) = @_;
            'p5negative( ' . $self->{arguments}->[0]->emit_javascript2( $level, 'scalar' ) . ')';
        },
        'prefix:<+>' => sub {
            my ($self, $level, $wantarray) = @_;
            '(' . $self->{arguments}->[0]->emit_javascript2( $level, $wantarray ) . ')';
        },
        'require' => sub {
            my ($self, $level, $wantarray) = @_;
            my $arg  = $self->{arguments}->[0];
            if ($arg->{is_version_string}) {
                # require VERSION
                return 'p5pkg["Perlito5"]["test_perl_version"]([' 
                        . Perlito5::Javascript2::to_str( $self->{arguments}[0] )
                    . '], ' . Perlito5::Javascript2::to_context($wantarray) . ')';
            }
            # require FILE
            'p5pkg["Perlito5::Grammar::Use"]["require"]([' 
                . Perlito5::Javascript2::to_str( $self->{arguments}[0] ) . ', ' 
                . ($self->{arguments}[0]{bareword} ? 1 : 0) 
            . '], ' . Perlito5::Javascript2::to_context($wantarray) . ')';
        },
        'select' => sub {
            my ($self, $level, $wantarray) = @_;
            'p5pkg["CORE"]["select"]([' 
                . ( $self->{arguments}[0]{bareword}
                  ? Perlito5::Javascript2::to_str( $self->{arguments}[0] )
                  : $self->{arguments}[0]->emit_javascript2( $level, 'scalar' ) )
            . '])';
        },
        'prefix:<$>' => sub {
            my ($self, $level, $wantarray) = @_;
            my $arg  = $self->{arguments}->[0];
            return 'p5scalar_deref(' 
                    . $arg->emit_javascript2( $level ) . ', '
                    . Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME) . ', '
                    . '""'      # autovivification type
                    . ')';
        },
        'prefix:<@>' => sub {
            my ($self, $level, $wantarray) = @_;
            my $arg   = $self->{arguments}->[0];
            my $s = 'p5array_deref(' 
                  . Perlito5::Javascript2::emit_javascript2_autovivify( $arg, $level, 'array' ) . ', '
                  . Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME)
                  . ')';
            return $wantarray eq 'scalar'
                ? "p5num($s)"
                : $s;
        },
        'prefix:<$#>' => sub {
            my ($self, $level, $wantarray) = @_;
            my $arg   = $self->{arguments}->[0];
            return '(p5array_deref(' 
                    . Perlito5::Javascript2::emit_javascript2_autovivify( $arg, $level, 'array' ) . ', '
                    . Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME)
                    . ').length - 1)';
        },
        'prefix:<%>' => sub {
            my ($self, $level, $wantarray) = @_;
            my $arg   = $self->{arguments}->[0];
            return 'p5hash_deref(' 
                    . Perlito5::Javascript2::emit_javascript2_autovivify( $arg, $level, 'hash' ) . ', '
                    . Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME)
                    . ')';
        },
        'prefix:<&>' => sub {
            my ($self, $level, $wantarray) = @_;
            my $arg   = $self->{arguments}->[0];
            'p5code_lookup_by_name(' . Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME ) . ', ' . $arg->emit_javascript2($level) . ')([])';
        },
        'circumfix:<[ ]>' => sub {
            my ($self, $level, $wantarray) = @_;
            '(new p5ArrayRef(' . Perlito5::Javascript2::to_list( $self->{arguments} ) . '))';
        },
        'circumfix:<{ }>' => sub {
            my ($self, $level, $wantarray) = @_;
            '(new p5HashRef(' . Perlito5::Javascript2::to_list( $self->{arguments}, $level, 'hash' ) . '))';
        },
        'prefix:<\\>' => sub {
            my ($self, $level, $wantarray) = @_;
            my $arg   = $self->{arguments}->[0];
            if ( $arg->isa('Perlito5::AST::Apply') ) {
                if ( $arg->{code} eq 'prefix:<@>' ) {
                    return '(new p5ArrayRef(' . $arg->emit_javascript2($level) . '))';
                }
                if ( $arg->{code} eq 'prefix:<%>' ) {
                    return '(new p5HashRef(' . $arg->emit_javascript2($level) . '))';
                }
                # if ( $arg->{code} eq '*' ) {
                #     # TODO
                #     return '(new p5GlobRef(' . $arg->emit_javascript2($level) . '))';
                # }
                if ( $arg->{code} eq 'circumfix:<( )>' ) {
                    # \( @x )
                    return 'p5_list_of_refs(' . Perlito5::Javascript2::to_list( $arg->{arguments} ) . ')';
                }
                if ( $arg->{code} eq 'prefix:<&>' ) {
                    return 'p5code_lookup_by_name(' . Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME ) . ', ' . $arg->{arguments}->[0]->emit_javascript2($level) . ')';
                }
            }
            if ( $arg->isa('Perlito5::AST::Var') ) {
                if ( $arg->sigil eq '@' ) {
                    return '(new p5ArrayRef(' . $arg->emit_javascript2($level) . '))';
                }
                if ( $arg->sigil eq '%' ) {
                    return '(new p5HashRef(' . $arg->emit_javascript2($level) . '))';
                }
                if ( $arg->sigil eq '*' ) {
                    return '(new p5GlobRef(' . $arg->emit_javascript2($level) . '))';
                }
                if ( $arg->sigil eq '&' ) {
                    if ( $arg->{namespace} ) {
                        return 'p5pkg[' . Perlito5::Javascript2::escape_string($arg->{namespace} ) . '].' . $arg->{name};
                    }
                    else {
                        return Perlito5::Javascript2::pkg() . '.' . $arg->{name};
                    }
                }
            }
            return '(new p5ScalarRef(' . $arg->emit_javascript2($level) . '))';
        },

        'postfix:<++>' => sub {
            my ($self, $level, $wantarray) = @_;
            my $arg   = $self->{arguments}->[0];
            if  (   $arg->isa( 'Perlito5::AST::Index')
                ||  $arg->isa( 'Perlito5::AST::Lookup') 
                ||  $arg->isa( 'Perlito5::AST::Call') 
                )
            {
                return $arg->emit_javascript2($level+1, 0, 'p5postincr');
            }
            if  (   $arg->isa( 'Perlito5::AST::Var')
                &&  $arg->{sigil} eq '$'
                )
            {
                my $tmp  = Perlito5::Javascript2::get_label();
                return Perlito5::Javascript2::emit_wrap_javascript2($level, 'scalar', 
                            'var ' . $tmp . ' = ' . $arg->emit_javascript2($level) . ';',
                            $arg->emit_javascript2($level) . ' = p5incr_(' . $tmp . ');',
                            'return ' . $tmp,
                )
            }
            '(' . join( ' ', map( $_->emit_javascript2, @{ $self->{arguments} } ) ) . ')++';
        },
        'postfix:<-->' => sub {
            my ($self, $level, $wantarray) = @_;
            my $arg   = $self->{arguments}->[0];

            if  (   $arg->isa( 'Perlito5::AST::Index')
                ||  $arg->isa( 'Perlito5::AST::Lookup') 
                ||  $arg->isa( 'Perlito5::AST::Call') 
                )
            {
                return $arg->emit_javascript2($level+1, 0, 'p5postdecr');
            }
            if  (   $arg->isa( 'Perlito5::AST::Var')
                &&  $arg->{sigil} eq '$'
                )
            {
                my $tmp  = Perlito5::Javascript2::get_label();
                return Perlito5::Javascript2::emit_wrap_javascript2($level, 'scalar', 
                            'var ' . $tmp . ' = ' . $arg->emit_javascript2($level) . ';',
                            $arg->emit_javascript2($level) . ' = p5decr_(' . $tmp . ');',
                            'return ' . $tmp,
                )
            }

            '(' . join( ' ', map( $_->emit_javascript2, @{ $self->{arguments} } ) ) . ')--';
        },
        'prefix:<++>' => sub {
            my ($self, $level, $wantarray) = @_;
            my $arg   = $self->{arguments}->[0];
            if  (   $arg->isa( 'Perlito5::AST::Index')
                ||  $arg->isa( 'Perlito5::AST::Lookup') 
                ||  $arg->isa( 'Perlito5::AST::Call') 
                )
            {
                return $arg->emit_javascript2($level+1, 0, 'p5incr');
            }
            if  (   $arg->isa( 'Perlito5::AST::Var')
                &&  $arg->{sigil} eq '$'
                )
            {
                my $tmp  = Perlito5::Javascript2::get_label();
                return Perlito5::Javascript2::emit_wrap_javascript2($level, 'scalar', 
                            'var ' . $tmp . ' = ' . $arg->emit_javascript2($level) . ';',
                            $arg->emit_javascript2($level) . ' = p5incr_(' . $tmp . ');',
                            'return ' . $arg->emit_javascript2($level+1),
                )
            }
            '++(' . join( ' ', map( $_->emit_javascript2, @{ $self->{arguments} } ) ) . ')';
        },
        'prefix:<-->' => sub {
            my ($self, $level, $wantarray) = @_;
            my $arg   = $self->{arguments}->[0];

            if  (   $arg->isa( 'Perlito5::AST::Index')
                ||  $arg->isa( 'Perlito5::AST::Lookup') 
                ||  $arg->isa( 'Perlito5::AST::Call') 
                )
            {
                return $arg->emit_javascript2($level+1, 0, 'p5decr');
            }
            if  (   $arg->isa( 'Perlito5::AST::Var')
                &&  $arg->{sigil} eq '$'
                )
            {
                my $tmp  = Perlito5::Javascript2::get_label();
                return Perlito5::Javascript2::emit_wrap_javascript2($level, 'scalar', 
                            'var ' . $tmp . ' = ' . $arg->emit_javascript2($level) . ';',
                            $arg->emit_javascript2($level) . ' = p5decr_(' . $tmp . ');',
                            'return ' . $arg->emit_javascript2($level+1),
                )
            }

            '--(' . join( ' ', map( $_->emit_javascript2, @{ $self->{arguments} } ) ) . ')';
        },

        'infix:<x>' => sub {
            my ($self, $level, $wantarray) = @_;
            my $arg   = $self->{arguments}->[0];
            if (  ref($arg) eq 'Perlito5::AST::Apply'
               && ( $arg->{code} eq 'circumfix:<( )>' || $arg->{code} eq 'list:<,>' )
               )
            {
                # ($v) x $i
                # qw( 1 2 3 ) x $i
                return 'p5list_replicate('
                           . $self->{arguments}->[0]->emit_javascript2($level, 'list') . ','
                           . Perlito5::Javascript2::to_num($self->{arguments}->[1], $level) . ', '
                           . ( $wantarray eq 'runtime' ? 'p5want' : $wantarray eq 'list' ? 1 : 0 )
                        . ')'
            }
            'p5str_replicate('
                           . Perlito5::Javascript2::to_str($self->{arguments}->[0], $level) . ','
                           . Perlito5::Javascript2::to_num($self->{arguments}->[1], $level) . ')'
        },

        'list:<.>' => sub {
            my ($self, $level, $wantarray) = @_;
            '(' . join( ' + ', map( Perlito5::Javascript2::to_str($_), @{ $self->{arguments} } ) ) . ')';
        },
        'list:<,>' => sub {
            my ($self, $level, $wantarray) = @_;
            Perlito5::Javascript2::to_list( $self->{arguments} );
        },
        'infix:<..>' => sub {
            my ($self, $level, $wantarray) = @_;
            return 'p5range(' . $self->{arguments}->[0]->emit_javascript2($level) . ', '
                              . $self->{arguments}->[1]->emit_javascript2($level) . ', '
                              . ( $wantarray eq 'runtime' ? 'p5want' : $wantarray eq 'list' ? 1 : 0 ) . ', '
                              . '"' . Perlito5::Javascript2::get_label() . '"' . ', '
                              . '0'
                        . ')'
        },
        'infix:<...>' => sub {
            my ($self, $level, $wantarray) = @_;
            return 'p5range(' . $self->{arguments}->[0]->emit_javascript2($level) . ', '
                              . $self->{arguments}->[1]->emit_javascript2($level) . ', '
                              . ( $wantarray eq 'runtime' ? 'p5want' : $wantarray eq 'list' ? 1 : 0 ) . ', '
                              . '"' . Perlito5::Javascript2::get_label() . '"' . ', '
                              . '1'
                        . ')'
        },
        'delete' => sub {
            my ($self, $level, $wantarray) = @_;
            my $arg = $self->{arguments}->[0];
            if ($arg->isa( 'Perlito5::AST::Lookup' )) {
                my $v = $arg->obj;
                if (  $v->isa('Perlito5::AST::Var')
                   && $v->sigil eq '$'
                   )
                {
                    return '(delete ' . $v->emit_javascript2() . '[' . $arg->autoquote($arg->{index_exp})->emit_javascript2($level) . '])';
                }
                return '(delete ' . $v->emit_javascript2() . '._hash_[' . $arg->autoquote($arg->{index_exp})->emit_javascript2($level) . '])';
            }
            if ($arg->isa( 'Perlito5::AST::Index' )) {
                my $v = $arg->obj;
                if (  $v->isa('Perlito5::AST::Var')
                   && $v->sigil eq '$'
                   )
                {
                    return '(delete ' . $v->emit_javascript2() . '[' . $arg->{index_exp}->emit_javascript2($level) . '])';
                }
                return '(delete ' . $v->emit_javascript2() . '._array_[' . $arg->{index_exp}->emit_javascript2($level) . '])';
            }
            if ($arg->isa( 'Perlito5::AST::Call' )) {
                if ( $arg->method eq 'postcircumfix:<{ }>' ) {
                    return '(delete ' . $arg->invocant->emit_javascript2() . '._hash_[' . Perlito5::AST::Lookup->autoquote($arg->{arguments})->emit_javascript2($level) . '])';
                }
                if ( $arg->method eq 'postcircumfix:<[ ]>' ) {
                    return '(delete ' . $arg->invocant->emit_javascript2() . '._array_[' . $arg->{arguments}->emit_javascript2($level) . '])';
                }
            }
            if (  $arg->isa('Perlito5::AST::Var')
               && $arg->sigil eq '&'
               )
            {
                die 'TODO delete &code';
                # my $name = $arg->{name};
                # my $namespace = $arg->{namespace} || $Perlito5::PKG_NAME;
                # return 'p5pkg[' . Perlito5::Javascript2::escape_string($namespace) . '].hasOwnProperty(' . Perlito5::Javascript2::escape_string($name) . ')';
            }
            if (  $arg->isa('Perlito5::AST::Apply')
               && $arg->{code} eq 'prefix:<&>'
               )
            {
                die 'TODO delete &$code';
                # my $arg2 = $arg->{arguments}->[0];
                # return 'p5sub_exists(' . Perlito5::Javascript2::to_str($arg2) . ', ' . Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME) . ')';
            }
        },

        'scalar' => sub {
            my ($self, $level, $wantarray) = @_;
            Perlito5::Javascript2::to_scalar($self->{arguments}, $level+1);
        },

        'ternary:<? :>' => sub {
            my ($self, $level, $wantarray) = @_;
            '( ' . Perlito5::Javascript2::to_bool( $self->{arguments}->[0] ) . ' ? ' . ( $self->{arguments}->[1] )->emit_javascript2( $level, $wantarray ) . ' : ' . ( $self->{arguments}->[2] )->emit_javascript2( $level, $wantarray ) . ')';
        },
        'my' => sub {
            my ($self, $level, $wantarray) = @_;
            # this is a side-effect of my($x,$y)
            'p5context(' . '[' . join( ', ', map( $_->emit_javascript2( $level, $wantarray ), @{ $self->{arguments} } ) ) . '], ' . ( $wantarray eq 'runtime' ? 'p5want' : $wantarray eq 'list' ? 1 : 0 ) . ')';
        },
        'our' => sub {
            my ($self, $level, $wantarray) = @_;
            # this is a side-effect of our($x,$y)
            'p5context(' . '[' . join( ', ', map( $_->emit_javascript2( $level, $wantarray ), @{ $self->{arguments} } ) ) . '], ' . ( $wantarray eq 'runtime' ? 'p5want' : $wantarray eq 'list' ? 1 : 0 ) . ')';
        },
        'local' => sub {
            my ($self, $level, $wantarray) = @_;
            # 'local ($x, $y[10])'
            'p5context(' . '[' . join( ', ', map( $_->emit_javascript2( $level, $wantarray ), @{ $self->{arguments} } ) ) . '], ' . ( $wantarray eq 'runtime' ? 'p5want' : $wantarray eq 'list' ? 1 : 0 ) . ')';
        },
        'circumfix:<( )>' => sub {
            my ($self, $level, $wantarray) = @_;
            'p5context(' . '[' . join( ', ', map( $_->emit_javascript2( $level, $wantarray ), @{ $self->{arguments} } ) ) . '], ' . ( $wantarray eq 'runtime' ? 'p5want' : $wantarray eq 'list' ? 1 : 0 ) . ')';
        },
        'infix:<=>' => sub {
            my ($self, $level, $wantarray) = @_;
            my $parameters = $self->{arguments}->[0];
            my $arguments  = $self->{arguments}->[1];

            if (   $parameters->isa( 'Perlito5::AST::Apply' )
               &&  ( $parameters->code eq 'my' || $parameters->code eq 'local' || $parameters->code eq 'circumfix:<( )>' )
               )
            {
                # my ($x, $y) = ...
                # local ($x, $y) = ...
                # ($x, $y) = ...

                if ( $wantarray eq 'void' ) {
                    my $tmp  = Perlito5::Javascript2::get_label();
                    return join( ";\n" . Perlito5::Javascript2::tab($level),
                            'var ' . $tmp  . ' = ' . Perlito5::Javascript2::to_list([$arguments], $level+1),
                            ( map $_->emit_javascript2_set_list($level, $tmp),
                                  @{ $parameters->arguments }
                            ),
                    );
                }

                my $tmp  = Perlito5::Javascript2::get_label();
                my $tmp2 = Perlito5::Javascript2::get_label();
                return Perlito5::Javascript2::emit_wrap_javascript2($level, $wantarray, 
                            'var ' . $tmp  . ' = ' . Perlito5::Javascript2::to_list([$arguments], $level+1) . ";",
                            'var ' . $tmp2 . ' = ' . $tmp . ".slice(0);",
                            ( map $_->emit_javascript2_set_list($level+1, $tmp) . ";",
                                  @{ $parameters->arguments }
                            ),
                            'return ' . $tmp2,
                );
            }
            return $parameters->emit_javascript2_set($arguments, $level+1, $wantarray);
        },

        'break' => sub {
            my ($self, $level, $wantarray) = @_;
            $Perlito5::THROW = 1;
            Perlito5::Javascript2::emit_wrap_statement_javascript2(
                $level,
                $wantarray, 
                'throw(new p5_error("break", ""))'
            );
        },
        'next' => sub {
            my ($self, $level, $wantarray) = @_;
            $Perlito5::THROW = 1;
            my $label =  $self->{arguments}[0]{code} || "";
            Perlito5::Javascript2::emit_wrap_statement_javascript2(
                $level,
                $wantarray, 
                'throw(new p5_error("next", ' . Perlito5::Javascript2::escape_string($label ) . '))'
            );
        },
        'last' => sub {
            my ($self, $level, $wantarray) = @_;
            $Perlito5::THROW = 1;
            my $label =  $self->{arguments}[0]{code} || "";
            Perlito5::Javascript2::emit_wrap_statement_javascript2(
                $level,
                $wantarray, 
                'throw(new p5_error("last", ' . Perlito5::Javascript2::escape_string($label ) . '))'
            );
        },
        'redo' => sub {
            my ($self, $level, $wantarray) = @_;
            $Perlito5::THROW = 1;
            my $label =  $self->{arguments}[0]{code} || "";
            Perlito5::Javascript2::emit_wrap_statement_javascript2(
                $level,
                $wantarray, 
                'throw(new p5_error("redo", ' . Perlito5::Javascript2::escape_string($label ) . '))'
            );
        },
        'return' => sub {
            my ($self, $level, $wantarray) = @_;
            $Perlito5::THROW = 1;
            Perlito5::Javascript2::emit_wrap_statement_javascript2(
                $level,
                $wantarray, 
                'throw(' . Perlito5::Javascript2::to_runtime_context( $self->{arguments}, $level+1 ) . ')'
            );
        },
        'goto' => sub {
            my ($self, $level, $wantarray) = @_;
            $Perlito5::THROW = 1;
            Perlito5::Javascript2::emit_wrap_statement_javascript2(
                $level,
                $wantarray, 
                'throw(' . $self->{arguments}->[0]->emit_javascript2($level) . ')'
            );
        },

        'do' => sub {
            my ($self, $level, $wantarray) = @_;

            my $arg = $self->{arguments}->[0];
            if ($arg->isa( "Perlito5::AST::Block" )) {
                # do BLOCK
                my $block = $arg->{stmts};
                return Perlito5::Javascript2::emit_wrap_javascript2(
                    $level,
                    $wantarray, 
                    (Perlito5::Javascript2::LexicalBlock->new( block => $block ))->emit_javascript2( $level + 1, $wantarray )
                )
            }

            # do EXPR
            my $tmp_strict = $Perlito5::STRICT;
            $Perlito5::STRICT = 0;
            my $ast =
                Perlito5::AST::Apply->new(
                    code => 'eval',
                    namespace => '',
                    arguments => [
                       Perlito5::AST::Apply->new(
                          code => 'do_file',
                          namespace => 'Perlito5::Grammar::Use',
                          arguments => $self->{arguments}
                        )
                    ],
                    _scope => Perlito5::Grammar::Scope->new_base_scope(),
                );
            my $js = $ast->emit_javascript2( $level, $wantarray );
            $Perlito5::STRICT = $tmp_strict;
            return $js;
        },

        'eval' => sub {
            my ($self, $level, $wantarray) = @_;
            $Perlito5::THROW = 1;   # we can return() from inside eval

            my $arg = $self->{arguments}->[0];
            my $eval;
            if ($arg->isa( "Perlito5::AST::Block" )) {
                # eval block

                $eval = Perlito5::AST::Apply->new(
                            code => 'do',
                            arguments => [$arg]
                        )->emit_javascript2( $level + 1, $wantarray );
            }
            else {
                # eval string

                # retrieve the parse-time env
                my $scope_perl5 = Perlito5::Dumper::ast_dumper( [$self->{_scope}] );
                my $m = Perlito5::Grammar::Expression::term_square( $scope_perl5, 0 );
                if (!$m || $m->{to} < length($scope_perl5) ) {
                    die "invalid internal scope in eval\n";
                }
                $m = Perlito5::Grammar::Expression::expand_list( Perlito5::Match::flat($m)->[2] );
                my $scope_js = '(new p5ArrayRef(' . Perlito5::Javascript2::to_list($m) . '))';

                $eval ='eval(p5pkg["Perlito5::Javascript2::Runtime"].perl5_to_js([' 
                            . Perlito5::Javascript2::to_str($arg) . ", "
                            . Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME) . ', '
                            . Perlito5::Javascript2::escape_string($wantarray) . ', '
                            . $scope_js
                        . "]))";
            }

            # TODO - test return() from inside eval

            my $context = Perlito5::Javascript2::to_context($wantarray);

            Perlito5::Javascript2::emit_wrap_javascript2($level, $wantarray,
                ( $context eq 'p5want'
                  ? ()
                  : "var p5want = " . $context . ";",
                ),
                "var r;",
                'p5pkg["main"]["v_@"] = "";',
                'var p5strict = p5pkg["Perlito5"]["v_STRICT"];',
                'p5pkg["Perlito5"]["v_STRICT"] = ' . $Perlito5::STRICT . ';',
                "try {",
                    [ 'r = ' . $eval . "",
                    ],
                "}",
                "catch(err) {",
                 [
                   "if (err instanceof p5_error && (err.type == 'last' || err.type == 'redo' || err.type == 'next')) {",
                        [ 'throw(err)' ],
                   '}',
                   "else if ( err instanceof p5_error || err instanceof Error ) {",
                     [ 'p5pkg["main"]["v_@"] = err;',
                       'if (p5str(p5pkg["main"]["v_@"]).substr(-1, 1) != "\n") {',
                           [ # try to add a stack trace
                             'try {' . "",
                                 [ 'p5pkg["main"]["v_@"] = p5pkg["main"]["v_@"] + "\n" + err.stack + "\n";',
                                 ],
                             '}',
                             'catch(err) { }',
                           ],
                       '}',
                     ],
                   "}",
                   "else {",
                     [ "return(err);",
                     ],
                   "}",
                 ],
                "}",
                'p5pkg["Perlito5"]["v_STRICT"] = p5strict;',
                "return r;",
            );
        },

        'substr' => sub {
            my ($self, $level, $wantarray) = @_;
            my $length = $self->{arguments}->[2];
            if ( $length && $length->isa('Perlito5::AST::Int') && $length->{int} > 0 ) {
                return Perlito5::Javascript2::to_str($self->{arguments}->[0]) 
                    . '.substr(' . Perlito5::Javascript2::to_num($self->{arguments}->[1]) . ', ' 
                                 . Perlito5::Javascript2::to_num($self->{arguments}->[2]) . ')'
            }
            my $arg_list = Perlito5::Javascript2::to_list_preprocess( $self->{arguments} );
            my $arg_code = Perlito5::Javascript2::to_list($arg_list);
            return 'CORE.substr(' 
                    . $arg_code . ', '
                    . Perlito5::Javascript2::to_context($wantarray)
                 . ')';
        },
        'undef' => sub {
            my ($self, $level, $wantarray) = @_;
            if ( $self->{arguments} && @{$self->{arguments}} ) {
                my $arg = $self->{arguments}[0];
                if (  ref( $arg ) eq 'Perlito5::AST::Var' 
                   && $arg->{sigil} eq '&'
                   )
                {
                    return '(delete p5pkg[' . Perlito5::Javascript2::escape_string(($arg->{namespace} || $Perlito5::PKG_NAME) ) . '][' . Perlito5::Javascript2::escape_string($arg->{name} ) . '])';
                }
                return '(' . $arg->emit_javascript2 . ' = null)'
            }
            return 'null'
        },
        'defined' => sub { 
            my ($self, $level, $wantarray) = @_;
            my $arg = $self->{arguments}[0];
            my $invocant;
            if (  ref( $arg ) eq 'Perlito5::AST::Apply' 
               && $arg->{code} eq 'prefix:<&>'
               )
            {
                my $arg2   = $arg->{arguments}->[0];
                $invocant = 'p5code_lookup_by_name(' . Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME ) . ', ' . $arg2->emit_javascript2($level) . ')';
            }
            elsif (  ref( $arg ) eq 'Perlito5::AST::Var' 
               && $arg->{sigil} eq '&'
               )
            {
                $invocant = 'p5pkg[' . Perlito5::Javascript2::escape_string(($arg->{namespace} || $Perlito5::PKG_NAME) ) . '][' . Perlito5::Javascript2::escape_string($arg->{name} ) . ']';
            }
            else {
                $invocant = $arg->emit_javascript2($level, 'scalar');
            }
            '(' . $invocant . ' != null)' 
        },
        'shift' => sub {
            my ($self, $level, $wantarray) = @_;
            if ( $self->{arguments} && @{$self->{arguments}} ) {
                return $self->{arguments}[0]->emit_javascript2( $level ) . '.shift()'
            }
            return 'List__.shift()'
        },
        'pop' => sub {
            my ($self, $level, $wantarray) = @_;
            if ( $self->{arguments} && @{$self->{arguments}} ) {
                return $self->{arguments}[0]->emit_javascript2( $level ) . '.pop()'
            }
            return 'List__.pop()'
        },
        'unshift' => sub {
            my ($self, $level, $wantarray) = @_;
            my @arguments = @{$self->{arguments}};
            my $v = shift @arguments;     # TODO - this argument can also be a 'Decl' instead of 'Var'

            return $v->emit_javascript2( $level ) . '.p5unshift(' . Perlito5::Javascript2::to_list(\@arguments) . ')';
        },
        'push' => sub {
            my ($self, $level, $wantarray) = @_;
            my @arguments = @{$self->{arguments}};
            my $v = shift @arguments;     # TODO - this argument can also be a 'Decl' instead of 'Var'

            return $v->emit_javascript2( $level ) . '.p5push(' . Perlito5::Javascript2::to_list(\@arguments) . ')';
        },
        'tie' => sub {
            my ($self, $level, $wantarray) = @_;
            my @arguments = @{$self->{arguments}};
            my $v = shift @arguments;     # TODO - this argument can also be a 'Decl' instead of 'Var'

            my $meth;
            if ( $v->isa('Perlito5::AST::Var') && $v->sigil eq '%' ) {
                $meth = 'hash';
            }
            elsif ( $v->isa('Perlito5::AST::Var') && $v->sigil eq '@' ) {
                $meth = 'array';
            }
            elsif ( $v->isa('Perlito5::AST::Var') && $v->sigil eq '$' ) {
                $meth = 'scalar';
            }
            else {
                die "tie '", ref($v), "' not implemented";
            }
            return 'p5tie_' . $meth . '(' . $v->emit_javascript2( $level ) . ', ' . Perlito5::Javascript2::to_list(\@arguments) . ')';
        },
        'untie' => sub {
            my ($self, $level, $wantarray) = @_;
            my @arguments = @{$self->{arguments}};
            my $v = shift @arguments;     # TODO - this argument can also be a 'Decl' instead of 'Var'

            my $meth;
            if ( $v->isa('Perlito5::AST::Var') && $v->sigil eq '%' ) {
                $meth = 'hash';
            }
            elsif ( $v->isa('Perlito5::AST::Var') && $v->sigil eq '@' ) {
                $meth = 'array';
            }
            elsif ( $v->isa('Perlito5::AST::Var') && $v->sigil eq '$' ) {
                $meth = 'scalar';
            }
            else {
                die "tie '", ref($v), "' not implemented";
            }
            return 'p5untie_' . $meth . '(' . $v->emit_javascript2( $level ) . ')';
        },
        'print' => sub {
            my ($self, $level, $wantarray) = @_;
            my @in  = @{$self->{arguments}};
            my $fun;
            if ( $self->{special_arg} ) {
                $fun  = $self->{special_arg}->emit_javascript2( $level );
            }
            else {
                $fun  = '"STDOUT"';
            }
            my $list = Perlito5::Javascript2::to_list(\@in);
            'p5pkg["Perlito5::IO"].print(' . $fun . ', ' . $list . ')';
        },
        'say' => sub {
            my ($self, $level, $wantarray) = @_;
            my @in  = @{$self->{arguments}};
            my $fun;
            if ( $self->{special_arg} ) {
                $fun  = $self->{special_arg}->emit_javascript2( $level );
            }
            else {
                $fun  = '"STDOUT"';
            }
            my $list = Perlito5::Javascript2::to_list(\@in);
            'p5pkg["Perlito5::IO"].say(' . $fun . ', ' . $list . ')';
        },
        'printf' => sub {
            my ($self, $level, $wantarray) = @_;
            my @in  = @{$self->{arguments}};
            my $fun;
            if ( $self->{special_arg} ) {
                $fun  = $self->{special_arg}->emit_javascript2( $level );
            }
            else {
                $fun  = '"STDOUT"';
            }
            my $list = Perlito5::Javascript2::to_list(\@in);
            'p5pkg["Perlito5::IO"].printf(' . $fun . ', ' . $list . ')';
        },
        'close' => sub {
            my ($self, $level, $wantarray) = @_;
            my @in  = @{$self->{arguments}};
            my $fun = shift(@in);
            'p5pkg["Perlito5::IO"].close(' . $fun->emit_javascript2( $level ) . ', [])';
        },
        'open' => sub {
            my ($self, $level, $wantarray) = @_;
            my @in  = @{$self->{arguments}};
            my $fun = shift(@in);
            if (ref($fun) ne 'Perlito5::AST::Apply') {
                # doesn't look like STDERR or FILE; initialize the variable with a GLOB
                return Perlito5::Javascript2::emit_wrap_javascript2($level, $wantarray,
                    $fun->emit_javascript2( $level ) . ' = CORE.bless([ {file_handle : {id : null}}, "GLOB" ]);',
                    'return CORE.open(' . Perlito5::Javascript2::to_list( $self->{arguments}, $level ) . ')'
                );
            }
            else {
                $Perlito5::STRICT = 0;  # allow FILE bareword
                return 'CORE.open(' . Perlito5::Javascript2::to_list( $self->{arguments}, $level ) . ')'
            }
        },
        'chomp' => sub {
            my ($self, $level, $wantarray) = @_;
            # TODO - chomp assignment: chomp($answer = <STDIN>)
            my $v  = $self->{arguments}[0];
            return Perlito5::Javascript2::emit_wrap_javascript2($level, $wantarray,
                'var r = p5chomp(' . Perlito5::Javascript2::to_str($v, $level) . ');',
                $v->emit_javascript2( $level ) . ' = r[1];',
                'return r[0]',
            );
        },
        'chop' => sub {
            my ($self, $level, $wantarray) = @_;
            my $v  = $self->{arguments}[0];
            return Perlito5::Javascript2::emit_wrap_javascript2($level, $wantarray,
                'var r = p5chop(' . Perlito5::Javascript2::to_str($v, $level) . ');',
                $v->emit_javascript2( $level ) . ' = r[1];',
                'return r[0]',
            );
        },
        'read' => sub {
            my ($self, $level, $wantarray) = @_;
            # read FILEHANDLE,SCALAR,LENGTH,OFFSET
            my @in  = @{$self->{arguments}};
            my $fun = shift(@in);
            my $scalar = shift(@in);
            my $length = shift(@in);
            return Perlito5::Javascript2::emit_wrap_javascript2($level, $wantarray,
                'var r = p5pkg["Perlito5::IO"].read(' . $fun->emit_javascript2( $level ) . ', [' . $length->emit_javascript2( $level ) . ']);',
                $scalar->emit_javascript2( $level ) . ' = r[1];',
                'return r[0]',
            );
        },
        'readline' => sub {
            my ($self, $level, $wantarray) = @_;
            # readline FILEHANDLE
            # TODO - special cases; see 'readline' and '<>' in "perldoc perlop"
            my @in  = @{$self->{arguments}};
            my $fun = shift(@in)
                || bless({
                       'arguments' => [],
                       'bareword' => 1,
                       'code' => 'ARGV',
                       'namespace' => '',
                   }, 'Perlito5::AST::Apply');
            return 'CORE.readline(['
                        . $fun->emit_javascript2( $level )
                . '], '
                . Perlito5::Javascript2::to_context($wantarray)
            . ')';
        },
        'map' => sub {
            my ($self, $level, $wantarray) = @_;
            my @in  = @{$self->{arguments}};

            my $fun;

            if ( $self->{special_arg} ) {
                # TODO - test 'special_arg' type (scalar, block, ...)
                $fun  = $self->{special_arg};
            }
            else {
                $fun  = shift @in;
            }
            my $list = Perlito5::Javascript2::to_list(\@in);

            if (ref($fun) eq 'Perlito5::AST::Block') {
                $fun = $fun->{stmts}
            }
            else {
                $fun = [$fun];
            }

            'p5map(' . Perlito5::Javascript2::pkg() . ', '
                    . 'function (p5want) {' . "\n"
                    . Perlito5::Javascript2::tab($level+1) . (Perlito5::Javascript2::LexicalBlock->new( block => $fun ))->emit_javascript2( $level + 1, $wantarray ) . "\n"
                    . Perlito5::Javascript2::tab($level) . '}, '
                    .   $list
                    . ')';
        },
        'grep' => sub {
            my ($self, $level, $wantarray) = @_;
            my @in  = @{$self->{arguments}};

            my $fun;

            if ( $self->{special_arg} ) {
                # TODO - test 'special_arg' type (scalar, block, ...)
                $fun  = $self->{special_arg};
            }
            else {
                $fun  = shift @in;
            }
            my $list = Perlito5::Javascript2::to_list(\@in);

            if (ref($fun) eq 'Perlito5::AST::Block') {
                $fun = $fun->{stmts}
            }
            else {
                $fun = [$fun];
            }

            'p5grep(' . Perlito5::Javascript2::pkg() . ', '

                    . 'function (p5want) {' . "\n"
                    . Perlito5::Javascript2::tab($level+1) . (Perlito5::Javascript2::LexicalBlock->new( block => $fun ))->emit_javascript2( $level + 1, $wantarray ) . "\n"
                    . Perlito5::Javascript2::tab($level) . '}, '

                    .   $list
                    . ')';
        },
        'sort' => sub {
            my ($self, $level, $wantarray) = @_;
            my @in  = @{$self->{arguments}};
            my $fun;
            my $list;

            if ( $self->{special_arg} ) {
                # TODO - test 'special_arg' type (scalar, block, ...)
                $fun  = $self->{special_arg};
            }
            else {
                if (ref($in[0]) eq 'Perlito5::AST::Block') {
                    # the sort function is optional
                    $fun  = shift @in;
                }
            }

            if (ref($fun) eq 'Perlito5::AST::Block') {
                # the sort function is optional
                $fun =
                      'function (p5want) {' . "\n"
                    . Perlito5::Javascript2::tab($level+1) . (Perlito5::Javascript2::LexicalBlock->new( block => $fun->{stmts} ))->emit_javascript2( $level + 1, $wantarray ) . "\n"
                    . Perlito5::Javascript2::tab($level) . '}'
            }
            else {
                $fun = 'null';
            }
            $list = Perlito5::Javascript2::to_list(\@in);

            'p5sort(' . Perlito5::Javascript2::pkg() . ', '
                    .   $fun . ', '
                    .   $list
                    . ')';
        },
        'infix:<//>' => sub { 
            my ($self, $level, $wantarray) = @_;
            'p5defined_or' . '('
                . $self->{arguments}->[0]->emit_javascript2($level, 'scalar') . ', '
                . Perlito5::Javascript2::emit_function_javascript2($level, $wantarray, $self->{arguments}->[1]) 
                . ')'
        },
        'exists' => sub {
            my ($self, $level, $wantarray) = @_;
            my $arg = $self->{arguments}->[0];
            if ($arg->isa( 'Perlito5::AST::Lookup' )) {
                my $v = $arg->obj;
                if (  $v->isa('Perlito5::AST::Var')
                   && $v->sigil eq '$'
                   )
                {
                    $v->{sigil} = '%';
                    return '(' . $v->emit_javascript2() . ').hasOwnProperty(' . $arg->autoquote($arg->{index_exp})->emit_javascript2($level) . ')';
                }
                return '(' . $v->emit_javascript2() . ')._hash_.hasOwnProperty(' . $arg->autoquote($arg->{index_exp})->emit_javascript2($level) . ')';
            }
            if ($arg->isa( 'Perlito5::AST::Index' )) {
                my $v = $arg->obj;
                if (  $v->isa('Perlito5::AST::Var')
                   && $v->sigil eq '$'
                   )
                {
                    return '(' . $v->emit_javascript2() . ').hasOwnProperty(' . $arg->{index_exp}->emit_javascript2($level) . ')';
                }
                return '(' . $v->emit_javascript2() . ')._array_.hasOwnProperty(' . $arg->{index_exp}->emit_javascript2($level) . ')';
            }
            if ($arg->isa( 'Perlito5::AST::Call' )) {
                if ( $arg->method eq 'postcircumfix:<{ }>' ) {
                    return Perlito5::Javascript2::emit_javascript2_autovivify( $arg->invocant, $level, 'hash' ) . '._hash_.hasOwnProperty(' . Perlito5::AST::Lookup->autoquote($arg->{arguments})->emit_javascript2($level) . ')';
                }
                if ( $arg->method eq 'postcircumfix:<[ ]>' ) {
                    return Perlito5::Javascript2::emit_javascript2_autovivify( $arg->invocant, $level, 'array' ) . '._array_.hasOwnProperty(' . $arg->{arguments}->emit_javascript2($level) . ')';
                }
            }
            if (  $arg->isa('Perlito5::AST::Var')
               && $arg->sigil eq '&'
               )
            {
                # TODO exist() + 'my sub'
                my $name = $arg->{name};
                my $namespace = $arg->{namespace} || $Perlito5::PKG_NAME;
                return 'p5pkg[' . Perlito5::Javascript2::escape_string($namespace) . '].hasOwnProperty(' . Perlito5::Javascript2::escape_string($name) . ')';
            }
            if (  $arg->isa('Perlito5::AST::Apply')
               && $arg->{code} eq 'prefix:<&>'
               )
            {
                my $arg2 = $arg->{arguments}->[0];
                return 'p5sub_exists(' . Perlito5::Javascript2::to_str($arg2) . ', ' . Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME) . ')';
            }
        },

        'prototype' => sub {
            my ($self, $level, $wantarray) = @_;
            my $arg = $self->{arguments}->[0];
            return 'p5sub_prototype(' . $arg->emit_javascript2() . ', ' . Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME) . ')';
        },
        'split' => sub {
            my ($self, $level, $wantarray) = @_;
            my @js;
            my $arg = $self->{arguments}->[0];
            if ( $arg
              && $arg->isa('Perlito5::AST::Apply')
              && $arg->{code} eq 'p5:m'
            ) {
                # first argument of split() is a regex
                push @js, 'new RegExp('
                        . $arg->{arguments}->[0]->emit_javascript2() . ', '
                        . Perlito5::Javascript2::escape_string($arg->{arguments}->[1]->{buf})
                    . ')';
                shift @{ $self->{arguments} };
            }
            return 'CORE.split('
                . '[' . join( ', ',
                    @js,
                    map( $_->emit_javascript2, @{ $self->{arguments} } ) )
                . '], '
                . Perlito5::Javascript2::to_context($wantarray)
            . ')';
        },
    );

    sub emit_javascript2 {
        my ($self, $level, $wantarray) = @_;

        my $apply = $self->op_assign();
        if ($apply) {
            return $apply->emit_javascript2( $level );
        }
        my $apply = $self->op_auto();
        if ($apply) {
            return $apply->emit_javascript2( $level );
        }

        my $code = $self->{code};

        if (ref $code ne '') {
            my @args = ();
            push @args, $_->emit_javascript2
                for @{$self->{arguments}};
            return '(' . $self->{code}->emit_javascript2( $level ) . ')(' . join(',', @args) . ')';
        }

        return $emit_js{$code}->($self, $level, $wantarray)
            if exists $emit_js{$code};

        if (exists $Perlito5::Javascript2::op_infix_js_str{$code}) {
            return '(' 
                . join( $Perlito5::Javascript2::op_infix_js_str{$code}, map { Perlito5::Javascript2::to_str($_, $level) } @{$self->{arguments}} )
                . ')'
        }
        if (exists $Perlito5::Javascript2::op_infix_js_num{$code}) {
            return '(' 
                . join( $Perlito5::Javascript2::op_infix_js_num{$code}, map { Perlito5::Javascript2::to_num($_, $level) } @{$self->{arguments}} )
                . ')'
        }
        if (exists $Perlito5::Javascript2::op_prefix_js_str{$code}) {
            return $Perlito5::Javascript2::op_prefix_js_str{$code} . '(' 
                . Perlito5::Javascript2::to_str($self->{arguments}[0])
                . ')'
        }

        if ($self->{namespace}) {
            if (  $self->{namespace} eq 'JS' 
               && $code eq 'inline'
               ) 
            {
                if ( $self->{arguments}->[0]->isa('Perlito5::AST::Buf') ) {
                    # JS::inline('var x = 123')
                    return $self->{arguments}[0]{buf};
                }
                else {
                    die "JS::inline needs a string constant";
                }
            }
            $code = 'p5pkg[' . Perlito5::Javascript2::escape_string($self->{namespace} ) . '].' . $code;
        }
        else {
            $code = Perlito5::Javascript2::pkg() . '.' . $code
        }

        my $sig;
        my $may_need_autoload;
        {
            my $name = $self->{code};
            my $namespace = $self->{namespace} || $Perlito5::PKG_NAME;
            my $effective_name = $namespace . "::" . $self->{code};
            if ( exists $Perlito5::PROTO->{$effective_name} ) {
                $sig = $Perlito5::PROTO->{$effective_name};
            }
            elsif ( (!$self->{namespace} || $namespace eq 'CORE')
                  && exists $Perlito5::CORE_PROTO->{"CORE::$name"}
                  )
            {
                $effective_name = "CORE::$name";
                $sig = $Perlito5::CORE_PROTO->{$effective_name};
            }
            elsif ( exists $Perlito5::PACKAGES->{$name} ) {
                # bareword is a package name
                return Perlito5::Javascript2::escape_string($name);
            }
            else {
                # this subroutine was never declared
                if ($self->{bareword}) {
                    # TODO: allow barewords where a glob is expected: open FILE, ...
                    if ( $Perlito5::STRICT ) {
                        die 'Bareword ' . Perlito5::Javascript2::escape_string($name ) . ' not allowed while "strict subs" in use';
                    }

                    # bareword doesn't call AUTOLOAD
                    return Perlito5::Javascript2::escape_string( 
                            ($self->{namespace} ? $self->{namespace} . '::' : "") . $name 
                        );
                }
                $may_need_autoload = 1;
            }
            # is there a sig override
            $sig = $self->{proto}
                if (exists $self->{proto});
        }

        if ($sig) {
            # warn "sig $effective_name $sig\n";
            my @out = ();
            my @in  = @{$self->{arguments} || []};

            # TODO - generate the right prototype

            my $close = ']';

            my $optional = 0;
            while (length $sig) {
                my $c = substr($sig, 0, 1);
                if ($c eq ';') {
                    $optional = 1;
                }
                elsif ($c eq '$' || $c eq '_') {
                    push @out, shift(@in)->emit_javascript2( $level + 1, 'scalar' ) if @in || !$optional;
                }
                elsif ($c eq '+') {

                    # The "+" prototype is a special alternative to "$" that will act like
                    # "\[@%]" when given a literal array or hash variable, but will otherwise
                    # force scalar context on the argument.
                    if (@in || !$optional) {
                        my $in = shift(@in);
                        if (  (  $in->isa('Perlito5::AST::Apply')
                              && $in->{code} eq 'prefix:<@>'
                              )
                           || (  $in->isa('Perlito5::AST::Var')
                              && $in->sigil eq '@'
                              )
                           || (  $in->isa('Perlito5::AST::Apply')
                              && $in->{code} eq 'prefix:<%>'
                              )
                           || (  $in->isa('Perlito5::AST::Var')
                              && $in->sigil eq '%'
                              )
                           )
                        {
                            push @out, $in->emit_javascript2( $level + 1, 'list' );
                        }
                        else {
                            push @out, $in->emit_javascript2( $level + 1, 'scalar' );
                        }
                    }
                }
                elsif ($c eq '@') {
                    $close = '].concat(' . Perlito5::Javascript2::to_list(\@in, $level + 1) . ')'
                        if @in || !$optional;
                    @in = ();
                }
                elsif ($c eq '&') {
                    push @out, shift(@in)->emit_javascript2( $level + 1, 'scalar' );
                }
                elsif ($c eq '*') {
                    if (@in || !$optional) {
                        my $arg = shift @in;
                        if ($arg->{bareword}) {
                            push @out, Perlito5::Javascript2::escape_string($arg->{code});
                        }
                        else {
                            push @out, $arg->emit_javascript2( $level + 1, 'scalar' );
                        }
                    }
                }
                elsif ($c eq '\\') {
                    if (substr($sig, 0, 2) eq '\\$') {
                        $sig = substr($sig, 1);
                        push @out, shift(@in)->emit_javascript2( $level + 1, 'scalar' ) if @in || !$optional;
                    }
                    elsif (substr($sig, 0, 2) eq '\\@'
                        || substr($sig, 0, 2) eq '\\%'
                        )
                    {
                        $sig = substr($sig, 1);
                        push @out, shift(@in)->emit_javascript2( $level + 1, 'list' ) if @in || !$optional;
                    }
                    elsif (substr($sig, 0, 5) eq '\\[@%]') {
                        $sig = substr($sig, 4);
                        push @out, shift(@in)->emit_javascript2( $level + 1, 'list' ) if @in || !$optional;
                    }
                    elsif (substr($sig, 0, 6) eq '\\[$@%]') {
                        $sig = substr($sig, 5);
                        push @out, shift(@in)->emit_javascript2( $level + 1, 'list' ) if @in || !$optional;
                    }
                }
                $sig = substr($sig, 1);
            }

            return $code . '([' . join(', ', @out) . $close . ', '
                        . Perlito5::Javascript2::to_context($wantarray)
                . ')';
        }

        my $arg_list = Perlito5::Javascript2::to_list_preprocess( $self->{arguments} );

        my $arg_code = 
            $self->{code} eq 'scalar'      # scalar() is special
            ?   '['
              .   join(', ', map( $_->emit_javascript2($level), @$arg_list ))
              . ']'
            : Perlito5::Javascript2::to_list($arg_list);


        if ( $may_need_autoload ) {
            # p5call_sub(namespace, name, list, p5want)
            my $name = $self->{code};
            my $namespace = $self->{namespace} || $Perlito5::PKG_NAME;
            return 'p5call_sub('
                    . Perlito5::Javascript2::escape_string($namespace) . ', '
                    . Perlito5::Javascript2::escape_string($name) . ', '
                    . $arg_code . ', '
                    . Perlito5::Javascript2::to_context($wantarray)
                 . ')';

        }

        $code . '('
                . $arg_code . ', '
                . Perlito5::Javascript2::to_context($wantarray)
              . ')';

    }

    sub emit_javascript2_set_list {
        my ($self, $level, $list) = @_;
        if ( $self->code eq 'undef' ) {
            return $list . '.shift()' 
        }
        if ( $self->code eq 'prefix:<$>' ) {
            return 'p5scalar_deref_set(' 
                . Perlito5::Javascript2::emit_javascript2_autovivify( $self->{arguments}->[0], $level+1, 'scalar' ) . ', '
                . $list . '.shift()'  . ', '
                . Perlito5::Javascript2::escape_string($Perlito5::PKG_NAME)
                . ')';
        }
        die "not implemented: assign to ", $self->code;
    }

    sub emit_javascript2_get_decl {
        my $self      = shift;
        my $code = $self->{code};
        if ($code eq 'my' || $code eq 'our' || $code eq 'state' || $code eq 'local') {
            return ( map {     ref($_) eq 'Perlito5::AST::Var'
                             ? Perlito5::AST::Decl->new(
                                 decl => $code,
                                 type => '',     # TODO - add type
                                 var  => $_,
                               )
                             : ()
                         }
                         @{ $self->{arguments} }
                   );
        }
        if ($code ne 'do' && $code ne 'eval') {
            return ( map  +( $_->emit_javascript2_get_decl ), 
                          @{ $self->{arguments} }
                   )
                if $self->{arguments};
        }
        return ()
    }
    sub emit_javascript2_has_regex {
        my $self      = shift;
        my $code = $self->{code};
        if ($code eq 'p5:m' || $code eq 'p5:s' || $code eq 'infix:<=~>' || $code eq 'infix:<!~>') {
            return 1;
        }
        return ()
    }
}

package Perlito5::AST::If;
{
    sub emit_javascript2 {
        my ($self, $level, $wantarray) = @_;
        my $cond = $self->{cond};

        # extract declarations from 'cond'
        my @str;
        my $old_level = $level;
        # print Perlito5::Dumper::Dumper($self);
        # print Perlito5::Dumper::Dumper($self->{cond});
        if ($cond) {
            my @var_decl = $cond->emit_javascript2_get_decl();
            for my $arg (@var_decl) {
                $level = $old_level + 1;
                push @str, $arg->emit_javascript2_init($level, $wantarray);
            }
        }

        my $body =
              ref($self->{body}) ne 'Perlito5::AST::Block'
            ? $self->{body} # may be undef
            : (!@{ $self->{body}->stmts })
            ? undef
            : $wantarray ne 'void'
            ? Perlito5::Javascript2::LexicalBlock->new( block => $self->{body}->stmts, )
            : Perlito5::Javascript2::LexicalBlock->new( block => $self->{body}->stmts, create_context => 1 );
        my $otherwise =
              ref($self->{otherwise}) ne 'Perlito5::AST::Block'
            ? $self->{otherwise}  # may be undef
            : (!@{ $self->{otherwise}->stmts })
            ? undef
            : $wantarray ne 'void'
            ? Perlito5::Javascript2::LexicalBlock->new( block => $self->{otherwise}->stmts )
            : Perlito5::Javascript2::LexicalBlock->new( block => $self->{otherwise}->stmts, create_context => 1 );
 
        my $s = 'if ( ' . Perlito5::Javascript2::to_bool($cond, $level + 1) . ' ) {';

        if ($body) {
            $s = $s . "\n"
            . Perlito5::Javascript2::tab($level + 1) . $body->emit_javascript2( $level + 1, $wantarray ) . "\n"
            . Perlito5::Javascript2::tab($level)     . '}';
        }
        else {
            $s = $s . "}";
        }

        if ($otherwise) {
            if ( @{ $otherwise->{block} } == 1 
               && ref($otherwise->{block}[0]) eq 'Perlito5::AST::If'
               )
            {
                $s = $s . "\n"
                . Perlito5::Javascript2::tab($level)     . 'else ' . $otherwise->{block}[0]->emit_javascript2( $level, $wantarray );
            }
            else {
                $s = $s . "\n"
                . Perlito5::Javascript2::tab($level)     . 'else {' . "\n"
                . Perlito5::Javascript2::tab($level + 1) .  $otherwise->emit_javascript2( $level + 1, $wantarray ) . "\n"
                . Perlito5::Javascript2::tab($level)     . '}';
            }
        }

        push @str, $s;

        if (@str) {
            $level = $old_level;
            # create js scope for 'my' variables
            return 
                  ( $wantarray ne 'void'
                  ? "return "
                  : ""
                  )
                . Perlito5::Javascript2::emit_wrap_javascript2($level, $wantarray, @str);
        }
        else {
            return join( "\n" . Perlito5::Javascript2::tab($level), @str );
        }

    }
    sub emit_javascript2_get_decl { () }
    sub emit_javascript2_has_regex { () }
}


package Perlito5::AST::When;
{
    sub emit_javascript2 {
        my ($self, $level, $wantarray) = @_;
        # TODO - special case when When is inside a Given block
        # TODO - special case when When is a statement modifier
        my $cond = $self->{cond};
        # extract declarations from 'cond'
        my @str;
        my $old_level = $level;
        # print Perlito5::Dumper::Dumper($self);
        # print Perlito5::Dumper::Dumper($self->{cond});
        if ($cond) {
            my @var_decl = $cond->emit_javascript2_get_decl();
            for my $arg (@var_decl) {
                $level = $old_level + 1;
                push @str, $arg->emit_javascript2_init($level, $wantarray);
            }
        }
        $cond = Perlito5::AST::Apply->new(
                'arguments' => [
                    Perlito5::AST::Var->new(
                        'name' => '_',
                        'namespace' => 'main',
                        'sigil' => '$',
                    ),
                    $cond,
                ],
                'code' => 'infix:<~~>',
                'namespace' => '',
            );
        my $next = Perlito5::AST::Apply->new(
                'arguments' => [],
                'bareword' => 1,
                'code' => 'next',
                'namespace' => '',
            );
        my $body =
              ref($self->{body}) ne 'Perlito5::AST::Block'
            ? Perlito5::Javascript2::LexicalBlock->new( block => [ $self->{body} ] )
            : (!@{ $self->{body}->stmts })
            ? undef
            : $wantarray ne 'void'
            ? Perlito5::Javascript2::LexicalBlock->new( block => $self->{body}->stmts, )
            : Perlito5::Javascript2::LexicalBlock->new( block => $self->{body}->stmts, create_context => 1 );
        push @{ $body->{block} }, $next; 
        my $s = 'if ( ' . Perlito5::Javascript2::to_bool($cond, $level + 1) . ' ) {';

        if ($body) {
            $s = $s . "\n"
            . Perlito5::Javascript2::tab($level + 1) . $body->emit_javascript2( $level + 1, $wantarray ) . "\n"
            . Perlito5::Javascript2::tab($level)     . '}';
        }
        else {
            $s = $s . "}";
        }
        push @str, $s;

        if (@str) {
            $level = $old_level;
            # create js scope for 'my' variables
            return 
                  ( $wantarray ne 'void'
                  ? "return "
                  : ""
                  )
                . Perlito5::Javascript2::emit_wrap_javascript2($level, $wantarray, @str);
        }
        else {
            return join( "\n" . Perlito5::Javascript2::tab($level), @str );
        }
    }
    sub emit_javascript2_get_decl { () }
    sub emit_javascript2_has_regex { () }
}


package Perlito5::AST::While;
{
    sub emit_javascript2 {
        my ($self, $level, $wantarray) = @_;
        my $cond = $self->{cond};

        # extract declarations from 'cond'
        my @str;
        my $old_level = $level;
        # print Perlito5::Dumper::Dumper($self);
        # print Perlito5::Dumper::Dumper($self->{cond});
        if ($cond) {
            my @var_decl = $cond->emit_javascript2_get_decl();
            for my $arg (@var_decl) {
                $level = $old_level + 1;
                push @str, $arg->emit_javascript2_init($level, $wantarray);
            }
        }

        # body is 'Perlito5::AST::Apply' in this construct:
        #   do { ... } while ...;
        if ( ref($self->{body}) eq 'Perlito5::AST::Apply' && $self->{body}{code} eq 'do' ) {
            push @str,
                  'do {'
                .   $self->{body}->emit_javascript2($level + 2, $wantarray) . "\n"
                . Perlito5::Javascript2::tab($level + 1) . '} while ('
                .   Perlito5::Javascript2::to_bool($cond, $level + 2)
                . ')';
        }
        else {
            my $body =
                  ref($self->{body}) ne 'Perlito5::AST::Block'
                ? [ $self->{body} ]
                : $self->{body}{stmts};
            push @str, 'p5while('
                    . "function () {\n"
                    . Perlito5::Javascript2::tab($level + 2) .   (Perlito5::Javascript2::LexicalBlock->new( block => $body ))->emit_javascript2($level + 2, $wantarray) . "\n"
                    . Perlito5::Javascript2::tab($level + 1) . '}, '
                    . Perlito5::Javascript2::emit_function_javascript2($level + 1, 'scalar', $cond) . ', '
                    . Perlito5::AST::Block::emit_javascript2_continue($self, $level, $wantarray) . ', '
                    . Perlito5::Javascript2::escape_string($self->{label} || "") . ', '
                    . '0'
                    . ')';
        }

        if (@str) {
            $level = $old_level;
            # create js scope for 'my' variables
            return Perlito5::Javascript2::emit_wrap_javascript2($level, $wantarray, @str);
        }
        else {
            return join( "\n" . Perlito5::Javascript2::tab($level), @str );
        }
    }
    sub emit_javascript2_get_decl { () }
    sub emit_javascript2_has_regex { () }
}

package Perlito5::AST::For;
{
    sub emit_javascript2 {
        my ($self, $level, $wantarray) = @_;
        my $body =
              ref($self->{body}) ne 'Perlito5::AST::Block'
            ? [ $self->{body} ]
            : $self->{body}{stmts};

        # extract declarations from 'cond'
        my @str;
        my $old_level = $level;
        # print Perlito5::Dumper::Dumper($self);
        # print Perlito5::Dumper::Dumper($self->{cond});
        my $cond = ref( $self->{cond} ) eq 'ARRAY'
                   ? $self->{cond}
                   : [ $self->{cond} ];
        for my $expr ( @$cond, $self->{topic} ) {
            if ($expr) {
                my @var_decl = $expr->emit_javascript2_get_decl();
                for my $arg (@var_decl) {
                    $level = $old_level + 1;
                    push @str, $arg->emit_javascript2_init($level, $wantarray);
                }
            }
        }
        # print Perlito5::Dumper::Dumper(\@str);

        if (ref($self->{cond}) eq 'ARRAY') {
            # C-style for
            # TODO - loop label
            # TODO - make continue-block a syntax error
            push @str, Perlito5::Javascript2::emit_wrap_javascript2($level, $wantarray,
                'var label = ' . Perlito5::Javascript2::escape_string(($self->{label} || "") ) . ';',
                'for ( '
                    . ( $self->{cond}[0] ? $self->{cond}[0]->emit_javascript2($level + 1) . '; '  : '; ' )
                    . ( $self->{cond}[1] ? Perlito5::Javascript2::to_bool($self->{cond}[1], $level + 1) . '; '  : '; ' )
                    . ( $self->{cond}[2] ? $self->{cond}[2]->emit_javascript2($level + 1) . ' '   : ''  )
                  . ') {',
                  [ 'var _redo;',
                    'do {',
                      [ '_redo = false;',
                        'try {',
                          [
                            Perlito5::Javascript2::LexicalBlock->new( block => $body )->emit_javascript2($level + 4, $wantarray),
                          ],
                        '}',
                        'catch(err) {',
                          [ 'if (err instanceof p5_error && (err.v == label || err.v == \'\')) {',
                              [ 'if (err.type == \'last\') { return }',
                                'else if (err.type == \'redo\') { _redo = true }',
                                'else if (err.type != \'next\') { throw(err) }',
                              ],
                            '}',
                            'else {',
                              [ 'throw(err)',
                              ],
                            '}',
                          ],
                        '}',
                      ],
                    '} while (_redo);',
                  ],
                '}',
            );
        }
        else {

            my $cond = Perlito5::Javascript2::to_list([$self->{cond}], $level + 1);

            my $topic = $self->{topic};

            my $decl = '';
            my $v = $topic;
            if ($v->{decl}) {
                $decl = $v->{decl};
                $v    = $v->{var};
            }
            else {
                $decl = $v->{_decl} || 'global';
            }
            my $namespace = $v->{namespace} || $v->{_namespace} || $Perlito5::PKG_NAME;
            my $s;
            if ($decl eq 'my' || $decl eq 'state') {
                my $sig = $v->emit_javascript2( $level + 1 );
                push @str,
                    '(function(){ '
                        . "var $sig; "
                        . 'p5for_lex('
                            . "function (v) { $sig = v }, "
                            . "function () {\n"
                            . Perlito5::Javascript2::tab($level + 2) .   (Perlito5::Javascript2::LexicalBlock->new( block => $body ))->emit_javascript2($level + 2, $wantarray) . "\n"
                            . Perlito5::Javascript2::tab($level + 1) . '}, '
                            .   $cond . ', '
                            . Perlito5::AST::Block::emit_javascript2_continue($self, $level, $wantarray) . ', '
                            . Perlito5::Javascript2::escape_string($self->{label} || "")
                        . ') '
                    . '})()';
            }
            else {
                # use global variable or $_
                push @str,
                       'p5for(' 
                        . 'p5make_package(' . Perlito5::Javascript2::escape_string($namespace ) . '), '
                        . '"v_' . $v->{name} . '", '
                        . 'function () {' . "\n"
                        . Perlito5::Javascript2::tab($level + 2) .  (Perlito5::Javascript2::LexicalBlock->new( block => $body ))->emit_javascript2($level + 2, $wantarray) . "\n"
                        . Perlito5::Javascript2::tab($level + 1) . '}, '
                        .   $cond . ', '
                        . Perlito5::AST::Block::emit_javascript2_continue($self, $level, $wantarray) . ', '
                        . Perlito5::Javascript2::escape_string($self->{label} || "")
                        . ')'
            }
        }

        if (@str > 1) {
            $level = $old_level;
            # create js scope for 'my' variables
            return Perlito5::Javascript2::emit_wrap_javascript2($level, $wantarray, @str);
        }
        else {
            return join( "\n" . Perlito5::Javascript2::tab($level), @str );
        }
    }
    sub emit_javascript2_get_decl { () }
    sub emit_javascript2_has_regex { () }
}

package Perlito5::AST::Sub;
{
    sub emit_javascript2 {
        my ($self, $level, $wantarray) = @_;
        my $prototype = defined($self->{sig}) 
                        ? Perlito5::Javascript2::escape_string($self->{sig}) 
                        : 'null';

        my $sub_ref = Perlito5::Javascript2::get_label();
        local $Perlito5::AST::Sub::SUB_REF = $sub_ref;
        my $js_block = Perlito5::Javascript2::LexicalBlock->new( block => $self->{block}{stmts} )->emit_javascript2_subroutine_body( $level + 2, 'runtime' );

        my $s = Perlito5::Javascript2::emit_wrap_javascript2($level, 'scalar', 
            "var $sub_ref;",
            "$sub_ref = function (List__, p5want) {",
                [ $js_block ],
            "};",
            "$sub_ref._prototype_ = $prototype;",
            "return $sub_ref",
        );

        if ( $self->{name} ) {
            return 'p5typeglob_set(' . Perlito5::Javascript2::escape_string($self->{namespace} ) . ', ' . Perlito5::Javascript2::escape_string($self->{name} ) . ', ' . $s . ')'
        }
        else {
            return $s;
        }
    }
    sub emit_javascript2_get_decl { () }
    sub emit_javascript2_has_regex { () }
}

package Perlito5::AST::Use;
{
    sub emit_javascript2 {
        my ($self, $level, $wantarray) = @_;
        Perlito5::Grammar::Use::emit_time_eval($self);
        if ($wantarray ne 'void') {
            return 'p5context([], p5want)';
        }
        else {
            return '// ' . $self->{code} . ' ' . $self->{mod} . "\n";
        }
    }
    sub emit_javascript2_get_decl { () }
    sub emit_javascript2_has_regex { () }
}

1;

=begin

=head1 NAME

Perlito5::Javascript2::Emit - Code generator for Perlito Perl5-in-Javascript2

=head1 SYNOPSIS

    $program->emit_javascript2()  # generated Perl5 code

=head1 DESCRIPTION

This module generates Javascript2 code for the Perlito compiler.

=head1 AUTHORS

Flavio Soibelmann Glock <fglock@gmail.com>.
The Pugs Team E<lt>perl6-compiler@perl.orgE<gt>.

=head1 COPYRIGHT

Copyright 2006, 2009, 2011, 2012 by Flavio Soibelmann Glock, Audrey Tang and others.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=end
