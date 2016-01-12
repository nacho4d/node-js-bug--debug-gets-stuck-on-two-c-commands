package Games::Solitaire::Verify::Solution::Base;

use strict;
use warnings;

=head1 NAME

Games::Solitaire::Verify::Solution::Base - common base class for
all Games::Solitaire::Verify::Solution::* classes.

=cut

use Games::Solitaire::Verify::Base (); use vars qw(@ISA); @ISA = (qw(Games::Solitaire::Verify::Base));

# "_ln" is line number
# "_i" is input filehandle.
sub _i
{
    my $self = shift;
    if (@_)
    {
        $self->{'_i'} = shift;
    }
    return $self->{'_i'};
}


sub _ln
{
    my $self = shift;
    if (@_)
    {
        $self->{'_ln'} = shift;
    }
    return $self->{'_ln'};
}


sub _variant
{
    my $self = shift;
    if (@_)
    {
        $self->{'_variant'} = shift;
    }
    return $self->{'_variant'};
}


sub _variant_params
{
    my $self = shift;
    if (@_)
    {
        $self->{'_variant_params'} = shift;
    }
    return $self->{'_variant_params'};
}


sub _state
{
    my $self = shift;
    if (@_)
    {
        $self->{'_state'} = shift;
    }
    return $self->{'_state'};
}


sub _move
{
    my $self = shift;
    if (@_)
    {
        $self->{'_move'} = shift;
    }
    return $self->{'_move'};
}


sub _reached_end
{
    my $self = shift;
    if (@_)
    {
        $self->{'_reached_end'} = shift;
    }
    return $self->{'_reached_end'};
}


# _l is short for _get_line()
sub _l
{
    my $s = shift;

    # We use this instead of the accessor for speed.
    $s->{_ln}++;

    my $ret;
    if (defined ( $ret = scalar (readline($s->{_i})) ))
    {
        $ret =~ s# +(\n?)$#$1#;
    }
    return $ret;
}

1;

