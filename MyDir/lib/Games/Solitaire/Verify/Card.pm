package Games::Solitaire::Verify::Card;

use warnings;
use strict;

=encoding utf8

=head1 NAME

Games::Solitaire::Verify::Card - a class wrapper for an individual
Solitaire card.

=cut

our $VERSION = '0.1601';

use Games::Solitaire::Verify::Base (); use vars qw(@ISA); @ISA = (qw(Games::Solitaire::Verify::Base));



sub _flipped
{
    my $self = shift;
    if (@_)
    {
        $self->{'_flipped'} = shift;
    }
    return $self->{'_flipped'};
}


sub _s
{
    my $self = shift;
    if (@_)
    {
        $self->{'_s'} = shift;
    }
    return $self->{'_s'};
}


sub data
{
    my $self = shift;
    if (@_)
    {
        $self->{'data'} = shift;
    }
    return $self->{'data'};
}


sub id
{
    my $self = shift;
    if (@_)
    {
        $self->{'id'} = shift;
    }
    return $self->{'id'};
}


sub rank
{
    my $self = shift;
    if (@_)
    {
        $self->{'rank'} = shift;
    }
    return $self->{'rank'};
}


sub suit
{
    my $self = shift;
    if (@_)
    {
        $self->{'suit'} = shift;
    }
    return $self->{'suit'};
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

    use Games::Solitaire::Verify::Card;

    # Initialise a Queen-of-Hearts
    my $queen_of_hearts = Games::Solitaire::Verify::Card->new(
        {
            string => "QH",
            id => 4,
            data => { %DATA },
        },
    );

=head1 METHODS

=cut

sub _recalc
{
    my ($self) = @_;

    $self->_s($self->to_string());

    return;
}

sub _card_num_normalize
{
    my $arg = shift;

    if (ref($arg) eq "")
    {
        return +{ map { $_ => $arg } (qw(t non_t)) };
    }
    else
    {
        return $arg
    }
}

my @card_nums =  (map { _card_num_normalize($_) }
    ("A", (2 .. 9),
    {
        't' => "T",
        'non_t' => "10",
    },
    , "J", "Q", "K"));

my %ranks_map = (map { $card_nums[$_]->{t} => ($_+1) } (0 .. $#card_nums));

my @suits_map_proto =
(
    ["H" => { name => "hearts",   color => "red", },],
    ["C" => { name => "clubs",    color => "black", },],
    ["D" => { name => "diamonds", color => "red", },],
    ["S" => { name => "spades",   color => "black", },],
);

my %suits_map = (map {@$_} @suits_map_proto);

=head2 $class->get_suits_seq()

Returns the expected sequence of the suits - "H", "S", "C", "D".

=cut

sub get_suits_seq
{
    my $class = shift;

    return [map { $_->[0] } @suits_map_proto];
}

=head2 $class->calc_rank($rank_string)

Calculates the numerical rank of the string passed as argument.

Example:

    my $ten = Games::Solitaire::Verify::Card->calc_rank("T")
    # Prints 10.
    print "$ten\n";

=cut

sub calc_rank
{
    my ($self, $s) = @_;

    return $ranks_map{$s};
}

=head2 $class->calc_rank_with_0($rank_string)

Same as calc_rank only supporting "0" as the zero'th card.

=cut

sub calc_rank_with_0
{
    my ($self, $str) = @_;

    if ($str eq "0")
    {
        return 0;
    }
    else
    {
        return $self->calc_rank($str);
    }
}

sub _from_string
{
    my ($self, $str) = @_;

    my $is_flipped = 0;

    if ($str =~ s{^<(.*)>$}{$1}ms)
    {
        $is_flipped = 1;
    }

    if (length($str) != 2)
    {
        die +(bless { 
            error => "string length is too long",
         }, 'Games::Solitaire::Verify::Exception::Parse::Card')
    }

    my ($rank, $suit) = split(//, $str);

    if (! defined($self->rank($self->calc_rank($rank))))
    {
        die +(bless { 
            error => "unknown rank",
         }, 'Games::Solitaire::Verify::Exception::Parse::Card::UnknownRank')
    }

    if (exists($suits_map{$suit}))
    {
        $self->suit($suit);
    }
    else
    {
        die +(bless { 
            error => "unknown suit",
         }, 'Games::Solitaire::Verify::Exception::Parse::Card::UnknownSuit')
    }

    $self->set_flipped($is_flipped);

    return;
}

sub _init
{
    my ($self, $args) = @_;

    if (exists($args->{string}))
    {
        $self->_from_string($args->{string});
        $self->_recalc();
    }

    if (exists($args->{id}))
    {
        $self->id($args->{id});
    }

    if (exists($args->{data}))
    {
        $self->data($args->{data});
    }


    return;
}

=head2 $card->data()

Arbitrary data that is associated with the card. Can hold any scalar.

=head2 $card->id()

A simple identifier that identifies the card. Should be a string.

=head2 $card->rank()

Returns the rank of the card as an integer. Ace is 1, 2-10 are 2-10;
J is 11, Q is 12 and K is 13.

=head2 $card->suit()

Returns "H", "C", "D" or "S" depending on the suit.

=head2 $card->color()

Returns "red" or "black" depending on the rank of the card.

=cut

sub color
{
    my ($self) = @_;

    return $self->color_for_suit($self->suit());
}

=head2 $card->color_for_suit($suit)

Get the color of the suit $suit (which may be different than the card's suit).

=cut

sub color_for_suit
{
    my ($self, $suit) = @_;

    return $suits_map{$suit}->{'color'};
}

=head2 my $copy = $card->clone();

Clones the card into a new copy.

=cut

sub clone
{
    my $self = shift;

    my $new_card = Games::Solitaire::Verify::Card->new();

    $new_card->data($self->data());
    $new_card->id($self->id());
    $new_card->suit($self->suit());
    $new_card->rank($self->rank());

    $new_card->_recalc();

    return $new_card;
}

=head2 $card->to_string()

Converts the card to a string representation.

=cut

sub _to_string_without_flipped
{
    my $self = shift;

    return $self->rank_to_string($self->rank()) . $self->suit();
}

sub to_string
{
    my $self = shift;

    my $s = $self->_to_string_without_flipped();

    return ($self->is_flipped ? "<$s>" : $s);
}

=head2 $card->fast_s()

A cached string representation. (Use with care).

=cut

sub fast_s
{
    return shift->_s;
}

=head2 $class->rank_to_string($rank_idx)

Converts the rank to a string.

=cut

{
    my @_t_nums = ('0', (map { $_->{t} } @card_nums));

sub rank_to_string
{
    my ($class, $rank) = @_;

    return $_t_nums[$rank];
}

}

=head2 $card->is_flipped()

Determines if the card is flipped.

=cut

sub is_flipped
{
    return shift->_flipped();
}

=head2 $card->set_flipped($flipped_bool)

Sets the card’s flipped status.

=cut

sub set_flipped
{
    my ($self, $v) = @_;

    $self->_flipped($v);

    $self->_recalc();

    return;
}

1; # End of Games::Solitaire::Verify::Card
