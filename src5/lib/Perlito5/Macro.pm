use v5;
package Perlito5::Macro;
use strict;

{
package Perlito5::AST::Apply;
use strict;

my %op = (
    'infix:<+=>'  => 'infix:<+>',
    'infix:<-=>'  => 'infix:<->',
    'infix:<*=>'  => 'infix:<*>',
    'infix:</=>'  => 'infix:</>',
    'infix:<||=>' => 'infix:<||>',
    'infix:<&&=>' => 'infix:<&&>',
    'infix:<|=>'  => 'infix:<|>',
    'infix:<&=>'  => 'infix:<&>',
    'infix:<//=>' => 'infix:<//>',
    'infix:<.=>'  => 'list:<.>',
    'infix:<x=>'  => 'infix:<x>',
);

sub op_assign {
    my $self = $_[0];

    my $code = $self->{code};
    return 0 if ref($code);

    if (exists( $op{$code} )) {
        return Perlito5::AST::Apply->new(
            code      => 'infix:<=>',
            arguments => [
                $self->{arguments}->[0],
                Perlito5::AST::Apply->new(
                    code      => $op{$code},
                    arguments => $self->{arguments},
                ),
            ]
        );
    }

    return 0;
}

my %op_auto = (
    'prefix:<++>'  => 1,
    'prefix:<-->'  => 1,
    'postfix:<++>' => 1,
    'postfix:<-->' => 1,
);

sub op_auto {
    my $self = $_[0];

    my $code = $self->{code};
    return 0 if ref($code);

    if (exists( $op_auto{$code} )) {
        #   ++( $v = 2 )
        #   do { $v = 2; ++$v }

        my $paren = $self->{arguments}[0];
        if ($paren->{code} eq 'circumfix:<( )>') {

            my $arg = $paren->{arguments}[-1];
            if ($arg->{code} eq 'infix:<=>') {

                my $var = $arg->{arguments}[0];

                return Perlito5::AST::Apply->new(
                    code => 'do',
                    arguments => [ Perlito5::AST::Block->new(
                        stmts => [
                            $paren,     # assignment
                            Perlito5::AST::Apply->new(
                                code => $code,  # autoincrement
                                arguments => [ $var ],
                            ),
                        ],
                    ) ],
                );
            }
        }
    }

    return 0;
}

} # /package


sub while_file {
    my $self = $_[0];
    return 0
        if ref($self) ne 'Perlito5::AST::While';
    my $cond = $self->{cond};
    if ($cond->isa('Perlito5::AST::Apply') && ($cond->{code} eq 'readline')) {
        # while (<>) ...  is rewritten as  while ( defined($_ = <>) ) { ...
        $self->{cond} = bless({
                'arguments' => [
                    bless({
                        'arguments' => [
                            Perlito5::AST::Var->new(
                                'name' => '_',
                                'namespace' => '',
                                'sigil' => '$',
                            ),
                            $cond,
                        ],
                        'code' => 'infix:<=>',
                        'namespace' => '',
                    }, 'Perlito5::AST::Apply'),
                ],
                'bareword' => '',
                'code' => 'defined',
                'namespace' => '',
            }, 'Perlito5::AST::Apply');
        return $self;
    }
    return 0;
}

=begin

=head1 NAME

Perlito5::Macro - Ast macros for Perlito

=head1 SYNOPSIS

    $ast = $ast.op_assign()

=head1 DESCRIPTION

This module implements some Ast transformations for the Perlito compiler.

=head1 AUTHORS

Flavio Soibelmann Glock <fglock@gmail.com>.
The Pugs Team E<lt>perl6-compiler@perl.orgE<gt>.

=head1 SEE ALSO

The Perl 6 homepage at L<http://dev.perl.org/perl6>.

The Pugs homepage at L<http://pugscode.org/>.

=head1 COPYRIGHT

Copyright 2011, 2012 by Flavio Soibelmann Glock.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=end

