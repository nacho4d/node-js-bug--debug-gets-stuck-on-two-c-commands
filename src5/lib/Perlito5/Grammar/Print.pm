
package Perlito5::Grammar::Print;

use strict;

our %Print = (
    print  => 1,
    printf => 1,
    say    => 1,
    exec   => 1,
    system => 1,
);

token print_decl { 'printf' | 'print' | 'say' | 'exec' | 'system' };

token the_object {
    [
        <before '$'> <Perlito5::Grammar::Sigil::term_sigil>
            <!before '+'>
            {
                $MATCH->{capture} = Perlito5::Match::flat($MATCH->{'Perlito5::Grammar::Sigil::term_sigil'})->[1];
            }
    |
        <before '{'> <Perlito5::Grammar::Block::block> 
            {
                $MATCH->{capture} = Perlito5::Match::flat($MATCH->{"Perlito5::Grammar::Block::block"});
            }
    |
        <typeglob>
            <!before '('>
            {
                $MATCH->{capture} = Perlito5::Match::flat($MATCH->{'typeglob'});
            }
    ]

    {
        my $pos = $MATCH->{to};
        my $m = Perlito5::Grammar::Space::ws($MATCH->{str}, $pos);
        $pos = $m->{to} if $m;

        my $s = substr($MATCH->{str}, $pos, 1);
        my $s2 = substr($MATCH->{str}, $pos, 2);

        # print Perlito5::Dumper::Dumper $MATCH;
        # print "after: $MATCH->{capture} $pos '$MATCH->{str}' '$s' '$s2'\n";

        if (  $s eq ',' 
           || $s eq '?'
           || $s2 eq '->' 
           || $s eq '[' 
           || $s eq '{' 
           ) 
        {
            return
        }
        if ( $s eq '+' ) {
            my $m = Perlito5::Grammar::Space::ws($MATCH->{str}, $pos + 1);
            if ($m) {
                return 
            }
            # print "space + non-space\n";
        }
        else {
            my $m = Perlito5::Grammar::Precedence::op_parse($MATCH->{str}, $pos, 1);
            my $next_op = $m ? Perlito5::Match::flat($m)->[1] : '';
            my $is_infix = Perlito5::Grammar::Precedence::is_fixity_type('infix', $next_op);
            # print "is_infix $is_infix '$next_op'\n";
            return if $is_infix;
        }
    }

};

sub typeglob {
    my $str = $_[0];
    my $pos = $_[1];

    my $p = $pos;
    my $m_namespace = Perlito5::Grammar::optional_namespace_before_ident( $str, $p );
    my $namespace = Perlito5::Match::flat($m_namespace);
    $p = $m_namespace->{to};
    my $m_name      = Perlito5::Grammar::ident( $str, $p );

    if (!$m_name) {
        if ($namespace) {
            # namespace without name - X::
            $m_namespace->{capture} = Perlito5::AST::Var->new(
                                          sigil => '::',
                                          name  => '',
                                          namespace => $namespace,
                                      );
            return $m_namespace;
        }
        return;
    }

    my $name = Perlito5::Match::flat($m_name);
    $p = $m_name->{to};

    if ( substr( $str, $p, 2) eq '::' ) {
        # ::X::y::
        $m_name->{to} = $p + 2;
        $m_name->{capture} = Perlito5::AST::Var->new(
                                 sigil => '::',
                                 name  => '',
                                 namespace => $namespace . '::' . $name,
                             );
        return $m_name;
    }

    my $effective_name = ( $namespace || $Perlito5::PKG_NAME ) . '::' . $name;
    if ( exists $Perlito5::PROTO->{$effective_name} || exists &{$effective_name} ) {
        # subroutine was predeclared
        return;
    }
    if ( (!$namespace || $namespace eq 'CORE')
          && exists $Perlito5::CORE_PROTO->{"CORE::$name"} 
       )
    {
        # subroutine comes from CORE
        return;
    }

    my $full_name = $name;
    $full_name = $namespace . '::' . $name if $namespace;

    # if ( $Perlito5::STRICT && ! $Perlito5::PACKAGES->{ $full_name } ) {
    #     die 'Bareword "' . $full_name . '" not allowed';
    # }

    $m_name->{capture} = Perlito5::AST::Var->new(
                             sigil => '::',
                             name  => '',
                             namespace => $full_name,
                         );
    return $m_name;
}

sub print_ast {
    my ($decl, $the_object, $expr) = @_;
    Perlito5::AST::Apply->new( 
        namespace   => '',
        code        => $decl,
        special_arg => $the_object,
        arguments   => $expr,
    )
}

token term_print {
    <print_decl> 
    <.Perlito5::Grammar::Space::opt_ws>
    [
        '('
            <.Perlito5::Grammar::Space::opt_ws>
            { $MATCH->{_scope} = $#Perlito5::SCOPE_STMT }
            [ <the_object>
              <Perlito5::Grammar::Expression::list_parse>
            | { # backtrack
                $#Perlito5::SCOPE_STMT = $MATCH->{_scope};
                return;
              }
            ]
        ')'

        { 
            my $list = Perlito5::Match::flat($MATCH->{'Perlito5::Grammar::Expression::list_parse'});
            return if !ref($list);
            $MATCH->{capture} = [
                'term',
                print_ast(
                    Perlito5::Match::flat($MATCH->{'print_decl'}),
                    Perlito5::Match::flat($MATCH->{'the_object'}),
                    Perlito5::Grammar::Expression::expand_list($list),
                ),
            ]
        }
    |
        { $MATCH->{_scope} = $#Perlito5::SCOPE_STMT }
        [ <the_object>
          <Perlito5::Grammar::Expression::list_parse>
        | { # backtrack
            $#Perlito5::SCOPE_STMT = $MATCH->{_scope};
            return;
          }
        ]

        { 
            my $list = Perlito5::Match::flat($MATCH->{'Perlito5::Grammar::Expression::list_parse'});
            return if !ref($list);
            $MATCH->{capture} = [
                'term',
                print_ast(
                    Perlito5::Match::flat($MATCH->{'print_decl'}),
                    Perlito5::Match::flat($MATCH->{'the_object'}),
                    Perlito5::Grammar::Expression::expand_list($list),
                ),
            ]
        }
    ]
};


Perlito5::Grammar::Precedence::add_term( 'print'  => \&term_print );
Perlito5::Grammar::Precedence::add_term( 'printf' => \&term_print );
Perlito5::Grammar::Precedence::add_term( 'say'    => \&term_print );
Perlito5::Grammar::Precedence::add_term( 'exec'   => \&term_print );
Perlito5::Grammar::Precedence::add_term( 'system' => \&term_print );


1;

=begin

=head1 NAME

Perlito5::Grammar::Print - Parser and AST generator for Perlito

=head1 SYNOPSIS

    term_print($str)

=head1 DESCRIPTION

This module parses source code for Perl 5 statements and generates Perlito5 AST.

=head1 AUTHORS

Flavio Soibelmann Glock <fglock@gmail.com>.
The Pugs Team E<lt>perl6-compiler@perl.orgE<gt>.

=head1 COPYRIGHT

Copyright 2013 by Flavio Soibelmann Glock and others.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=end

