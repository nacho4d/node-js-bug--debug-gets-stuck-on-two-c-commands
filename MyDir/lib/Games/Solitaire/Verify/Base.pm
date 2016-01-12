package Games::Solitaire::Verify::Base;

use strict;
use warnings;

=head1 NAME

Games::Solitaire::Verify::Base - a base class.

=cut

use vars qw($VERSION);

$VERSION = '0.1601';

use Class::XSAccessor;

=head1 SYNOPSIS

    use parent 'Games::Solitaire::Verify::Base';

    sub _init
    {
        my ($self, $args) = @_;

        $self->address($args->{address});

        if (!exists($args->{name}))
        {
            die "No name - no cry.";
        }

        return;
    }

=head1 DESCRIPTION

This is the base class for L<Games::Solitaire::Verify> classes.
Everything is subject to change.

=cut

=head1 METHODS

=head2 new($args)

The constructor. Blesses and calls _init() .

=cut

sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;

    # May throw an exception.
    $self->_init(@_);

    return $self;
}

=head2 __PACKAGE__->mk_accessors(qw(method1 method2 method3))

Equivalent to L<Class::Accessor>'s mk_accessors only using Class::XSAccessor.
It beats running an ugly script on my code, and can be done at run-time.

Gotta love dynamic languages like Perl 5.

=cut

sub mk_accessors
{
    my $package = shift;
    return $package->mk_acc_ref([@_]);
}

=head2 __PACKAGE__->mk_acc_ref([qw(method1 method2 method3)])

Creates the accessors in the array-ref of names at run-time.

=cut

sub mk_acc_ref
{
    my $pkg = shift;
    my $names = shift;

    my $mapping = +{ map { $_ => $_ } @$names };

    {
        foreach my $meth_name (keys %$mapping)
        {
            my $slot = $mapping->{$meth_name};

            {
                no strict;
                *{"${pkg}::$meth_name"} = sub {
                    my $self = shift;

                    if (@_)
                    {
                        $self->{$slot} = shift;
                    }
                    return $self->{$slot};
                };
            }
        }
    }
}

1; # End of Games::Solitaire::Verify::Base

