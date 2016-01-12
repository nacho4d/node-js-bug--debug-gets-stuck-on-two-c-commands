package Games::Solitaire::Verify::VariantParams;

use warnings;
use strict;

=head1 NAME

Games::Solitaire::Verify::VariantParams - a class for holding
the parameters of the variant.

=cut

our $VERSION = '0.1601';

use Games::Solitaire::Verify::Base (); use vars qw(@ISA); @ISA = (qw(Games::Solitaire::Verify::Base));



sub empty_stacks_filled_by
{
    my $self = shift;
    if (@_)
    {
        $self->{'empty_stacks_filled_by'} = shift;
    }
    return $self->{'empty_stacks_filled_by'};
}


sub num_columns
{
    my $self = shift;
    if (@_)
    {
        $self->{'num_columns'} = shift;
    }
    return $self->{'num_columns'};
}


sub num_decks
{
    my $self = shift;
    if (@_)
    {
        $self->{'num_decks'} = shift;
    }
    return $self->{'num_decks'};
}


sub num_freecells
{
    my $self = shift;
    if (@_)
    {
        $self->{'num_freecells'} = shift;
    }
    return $self->{'num_freecells'};
}


sub rules
{
    my $self = shift;
    if (@_)
    {
        $self->{'rules'} = shift;
    }
    return $self->{'rules'};
}


sub seq_build_by
{
    my $self = shift;
    if (@_)
    {
        $self->{'seq_build_by'} = shift;
    }
    return $self->{'seq_build_by'};
}


sub sequence_move
{
    my $self = shift;
    if (@_)
    {
        $self->{'sequence_move'} = shift;
    }
    return $self->{'sequence_move'};
}


=head1 SYNOPSIS

    use Games::Solitaire::Verify::VariantParams;

    my $freecell_params =
        Games::Solitaire::Verify::VariantParams->new(
            {
                seq_build_by => "alt_color",
            },
        );


=head1 METHODS

=cut

my %seqs_build_by = (map { $_ => 1 } (qw(alt_color suit rank)));
my %empty_stacks_filled_by_map = (map { $_ => 1 } (qw(kings any none)));
my %seq_moves = (map { $_ => 1 } (qw(limited unlimited)));
my %rules_collection = (map { $_ => 1 } (qw(freecell simple_simon)));

sub _init
{
    my ($self, $args) = @_;

    # Set the variant
    #

    {
        my $seq_build_by = $args->{seq_build_by};

        if (!exists($seqs_build_by{$seq_build_by}))
        {
            die +(bless { 
                    error => "Unrecognised seq_build_by",
                    value => $seq_build_by,
             }, 'Games::Solitaire::Verify::Exception::VariantParams::Param::SeqBuildBy')
        }
        $self->seq_build_by($seq_build_by);
    }

    {
        my $esf = $args->{empty_stacks_filled_by};

        if (!exists($empty_stacks_filled_by_map{$esf}))
        {
            die +(bless { 
                    error => "Unrecognised empty_stacks_filled_by",
                    value => $esf,
             }, 'Games::Solitaire::Verify::Exception::VariantParams::Param::EmptyStacksFill')
        }

        $self->empty_stacks_filled_by($esf);
    }

    {
        my $num_decks = $args->{num_decks};

        if (! (($num_decks == 1) || ($num_decks == 2)) )
        {
            die +(bless { 
                    error => "Wrong Number of Decks",
                    value => $num_decks,
             }, 'Games::Solitaire::Verify::Exception::VariantParams::Param::NumDecks')
        }
        $self->num_decks($num_decks);
    }

    {
        my $num_columns = $args->{num_columns};

        if (($num_columns =~ /\D/)
                ||
            ($num_columns == 0))
        {
            die +(bless { 
                    error => "num_columns is not a number",
                    value => $num_columns,
             }, 'Games::Solitaire::Verify::Exception::VariantParams::Param::Stacks')
        }
        $self->num_columns($num_columns)
    }

    {
        my $num_freecells = $args->{num_freecells};

        if ($num_freecells =~ /\D/)
        {
            die +(bless { 
                    error => "num_freecells is not a number",
                    value => $num_freecells,
             }, 'Games::Solitaire::Verify::Exception::VariantParams::Param::Freecells')
        }
        $self->num_freecells($num_freecells);
    }

    {
        my $seq_move = $args->{sequence_move};

        if (!exists($seq_moves{$seq_move}))
        {
            die +(bless { 
                    error => "Unrecognised sequence_move",
                    value => $seq_move,
             }, 'Games::Solitaire::Verify::Exception::VariantParams::Param::SeqMove')
        }

        $self->sequence_move($seq_move);
    }

    {
        my $rules = $args->{rules} || "freecell";

        if (!exists($rules_collection{$rules}))
        {
            die +(bless { 
                    error => "Unrecognised rules",
                    value => $rules,
             }, 'Games::Solitaire::Verify::Exception::VariantParams::Param::Rules')
        }
        $self->rules($rules);
    }

    return 0;
}

=head2 $variant_params->empty_stacks_filled_by()

What empty stacks can be filled by:

=over 4

=item * any

=item * none

=item * kings

=back

=head2 $variant_params->num_columns()

The number of columns the variant has.

=head2 $variant_params->num_decks()

The numbe of decks the variant has.

=head2 $variant_params->num_freecells()

The number of freecells the variant has.

=head2 $variant_params->rules()

The rules by which the variant obides:

=over 4

=item * freecell

=item * simple_simon

=back

=head2 $variant_params->seq_build_by()

Returns the sequence build by:

=over 4

=item * alt_color

=item * suit

=back

=head2 $variant_params->sequence_move()

=over 4

=item * limited

=item * unlimited

=back

=cut

=head2 $self->clone()

Returns a clone.

=cut

sub clone
{
    my $self = shift;

    return __PACKAGE__->new(
        {
            empty_stacks_filled_by => $self->empty_stacks_filled_by(),
            num_columns => $self->num_columns(),
            num_decks => $self->num_decks(),
            num_freecells => $self->num_freecells(),
            rules => $self->rules(),
            seq_build_by => $self->seq_build_by(),
            sequence_move => $self->sequence_move(),
        }
    );
}

1;
