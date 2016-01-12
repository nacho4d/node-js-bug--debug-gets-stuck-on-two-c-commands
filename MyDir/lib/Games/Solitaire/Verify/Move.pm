package Games::Solitaire::Verify::Move;

use warnings;
use strict;

=head1 NAME

Games::Solitaire::Verify::Move - a class wrapper for an individual
Solitaire move.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.1601';

use Games::Solitaire::Verify::Base (); use vars qw(@ISA); @ISA = (qw(Games::Solitaire::Verify::Base));



sub source_type
{
    my $self = shift;
    if (@_)
    {
        $self->{'source_type'} = shift;
    }
    return $self->{'source_type'};
}


sub dest_type
{
    my $self = shift;
    if (@_)
    {
        $self->{'dest_type'} = shift;
    }
    return $self->{'dest_type'};
}


sub source
{
    my $self = shift;
    if (@_)
    {
        $self->{'source'} = shift;
    }
    return $self->{'source'};
}


sub dest
{
    my $self = shift;
    if (@_)
    {
        $self->{'dest'} = shift;
    }
    return $self->{'dest'};
}


sub num_cards
{
    my $self = shift;
    if (@_)
    {
        $self->{'num_cards'} = shift;
    }
    return $self->{'num_cards'};
}


sub _game
{
    my $self = shift;
    if (@_)
    {
        $self->{'_game'} = shift;
    }
    return $self->{'_game'};
}


=head1 SYNOPSIS

    use Games::Solitaire::Verify::Move;

    my $move1 = Games::Solitaire::Verify::Move->new(
        {
            fcs_string => "Move a card from stack 0 to the foundations",
            game => "freecell",
        },
    );

=head1 FUNCTIONS

=cut

sub _from_fcs_string
{
    my ($self, $str) = @_;

    if ($str =~ m{^Move a card from stack (\d+) to the foundations$})
    {
        my $source = $1;

        $self->source_type("stack");
        $self->dest_type("foundation");

        $self->source($source);
    }
    elsif ($str =~ m{^Move a card from freecell (\d+) to the foundations$})
    {
        my $source = $1;

        $self->source_type("freecell");
        $self->dest_type("foundation");

        $self->source($source);
    }
    elsif ($str =~ m{^Move a card from freecell (\d+) to stack (\d+)$})
    {
        my ($source, $dest) = ($1, $2);

        $self->source_type("freecell");
        $self->dest_type("stack");

        $self->source($source);
        $self->dest($dest);
    }
    elsif ($str =~ m{^Move a card from stack (\d+) to freecell (\d+)$})
    {
        my ($source, $dest) = ($1, $2);

        $self->source_type("stack");
        $self->dest_type("freecell");

        $self->source($source);
        $self->dest($dest);
    }
    elsif ($str =~ m{^Move (\d+) cards from stack (\d+) to stack (\d+)$})
    {
        my ($num_cards, $source, $dest) = ($1, $2, $3);

        $self->source_type("stack");
        $self->dest_type("stack");

        $self->source($source);
        $self->dest($dest);
        $self->num_cards($num_cards);
    }
    elsif ($str =~ m{^Move the sequence on top of Stack (\d+) to the foundations$})
    {
        my $source = $1;

        $self->source_type("stack_seq");
        $self->dest_type("foundation");

        $self->source($source);
    }
    else
    {
        die +(bless { 
            error => "Cannot parse 'FCS' String",
         }, 'Games::Solitaire::Verify::Exception::Parse::FCS')
    }
}

sub _init
{
    my ($self, $args) = @_;

    $self->_game($args->{game});

    if (exists($args->{fcs_string}))
    {
        return $self->_from_fcs_string($args->{fcs_string});
    }
}

=head1 METHODS

=head2 $move->source_type()

Accessor for the solitaire card game's board layout's type -
C<"stack">, C<"freecell">, etc. used in the layout.

=head2 $move->dest_type()

Accessor for the destination type - C<"stack">, C<"freecell">,
C<"destination">.

=head2 $move->source()

The index number of the source.

=head2 $move->dest()

The index number of the destination.

=head2 $move->num_cards()

Number of cards affects - only relevant for a stack-to-stack move usually.

=cut

1; # End of Games::Solitaire::Verify::Move
