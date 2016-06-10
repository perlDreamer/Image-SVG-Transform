package Image::SVG::Transform;
use strict;
use warnings;
use Math::Trig qw/deg2rad/;

use Clone qw/clone/;

=head1 NAME

Image::SVG::Transform - read the "transform" attribute of an SVG element

=head1 SYNOPSIS

    use Image::SVG::Transform;
    my $transform = Image::SVG::Transform->new();
    $transform->extract_transforms('scale(0.5)');
    my $view_point = $transform->untransform([5, 10]);

=head1 DESCRIPTION

This module parses and converts the contents of the transform attribute in SVG into
a series of array of hashes, and then provide a convenience method for doing point transformation
from the transformed space to the viewpoint space.

=cut

use warnings;
use strict;
use Moo;
use Carp qw/croak/;
use Math::Matrix;

our $VERSION = '0.01';

has transforms => (
    is => 'rw',
    default => sub { [] },
);

##Borrowed parsing code from Image::SVG::Path
my $split_re = qr/
		     (?:
			 ,
		     |
			 (?<!e)(?=-)
		     |
			 \s+
		     )
		 /x;

my $comma_wsp = qr/ (?: \s+ ,? \s*)|(?: , \s* )/x;
my $number_re = qr/[-0-9.,e]+/i;
my $numbers_re = qr/(?:$number_re|\s)*/;

my $valid_transforms = {
    scale     => 2,
    translate => 2,
    rotate    => 3,
    skewX     => 1,
    skewY     => 1,
    matrix    => 6,
};

sub extract_transforms {
    my $self      = shift;
    my $transform = shift;
    ##Possible transforms:
    ## scale (x [y])
    ## translate (x [y])
    ## Start with trimming
    $transform =~ s/^\s*//;
    $transform =~ s/^\s*$//;

    my @transformers = ();
    while ($transform =~ m/\G (\w+) \s* \( \s* ($numbers_re) \s* \) (?:$comma_wsp)? /gx ) {
        push @transformers, [$1, $2];
    }

    if (! @transformers) {
        croak "Image::SVG::Transform: Unable to parse the transform string $transform";
    }
    my @transforms = ();
    foreach my $transformer (@transformers) {
        my ($transform_type, $params) = @{ $transformer };
        my @params = split $split_re, $params;
        ##Global checks
        croak "Unknown transform $transform_type" unless exists $valid_transforms->{$transform_type};
        croak "No parameters for transform $transform_type" unless scalar @params;
        croak "Too many parameters ".scalar(@params). " for transform $transform_type" if scalar(@params) > $valid_transforms->{$transform_type};
        ##Command specific checks
        if ($transform_type eq 'rotate' && @params == 2) {
            croak 'rotate transform may not have two parameters';
        }
        elsif ($transform_type eq 'matrix' && @params != 6) {
            croak 'matrix transform must have exactly six parameters';
        }
        if ($transform_type eq 'rotate' && @params == 3) {
            ##Special rotate with pre- and post-translates
            push @transforms,
            {
                type => 'translate',
                params => [ $params[1], $params[2] ],
            },
            {
                type => 'rotate',
                params => [ $params[0], ],
            },
            {
                type => 'translate',
                params => [ -1*$params[1], -1*$params[2] ],
            },
        }
        else {
            push @transforms, {
                type => $transform_type,
                params => \@params,
            }
        }
    }
    $self->transforms(\@transforms);
}

sub transform {
    my $self  = shift;
    my $point = shift;
    return $point unless @{ $self->transforms };
    push @{ $point }, 0; ##pad with zero to make a 1x3 matrix
    my $ctm = $self->get_ctm();
    my $userspace = Math::Matrix->new(
        [ $point->[0] ],
        [ $point->[1] ],
        [ 1 ],
    );
    my $viewport = $ctm->multiply($userspace);
    my $reverted_point = [ $viewport->[0]->[0], $viewport->[1]->[0] ];
    return $reverted_point;
}

sub get_ctm {
    my $self = shift;
    my $ctm = $self->_generate_matrix(0);
    my $idx = 1;
    while ($idx < scalar @{ $self->transforms }) {
        my $matrix = $self->_generate_matrix($idx);
        my $product = $matrix->multiply($ctm);
        $ctm = $product;
        $idx++;
    }
    return $ctm;
}

sub _generate_matrix {
    my $self = shift;
    my $index = shift;
    my $t = $self->transforms->[$index];
    my @matrix;
    if ($t->{type} eq 'translate') {
        my $tx = $t->{params}->[0];
        my $ty = defined $t->{params}->[1] ? $t->{params}->[0] : 0;
        @matrix = (
            [ 1, 0, $tx, ],
            [ 0, 1, $ty, ],
            [ 0, 0, 1, ],
        );
    }
    elsif ($t->{type} eq 'scale') {
        my $sx = $t->{params}->[0];
        my $sy = defined $t->{params}->[1] ? $t->{params}->[1] : $sx;
        @matrix = (
            [ $sx, 0,   0, ],
            [ 0,   $sy, 0, ],
            [ 0,   0,   1, ],
        );
    }
    elsif ($t->{type} eq 'scale') {
        my $sx = $t->{params}->[0];
        my $sy = defined $t->{params}->[1] ? $t->{params}->[1] : $sx;
        @matrix = (
            [ $sx, 0,   0, ],
            [ 0,   $sy, 0, ],
            [ 0,   0,   1, ],
        );
    }
    elsif ($t->{type} eq 'rotate') {
        my $angle = deg2rad($t->{params}->[0]);
        my $cosa  = cos $angle;
        my $sina  = sin $angle;
        @matrix = (
            [ $cosa, -1*$sina,  0, ],
            [ $sina,    $sina,  0, ],
            [ 0,            0,  1, ],
        );
    }
    elsif ($t->{type} eq 'skewX') {
        my $angle = deg2rad($t->{params}->[0]);
        my $tana  = tan $angle;
        @matrix = (
            [ 1, $tana,  0, ],
            [ 0,     1,  0, ],
            [ 0,     0,  1, ],
        );
    }
    elsif ($t->{type} eq 'skewY') {
        my $angle = deg2rad($t->{params}->[0]);
        my $tana  = tan $angle;
        @matrix = (
            [ 1,     0,  0, ],
            [ $tana, 1,  0, ],
            [ 0,     0,  1, ],
        );
    }
    elsif ($t->{type} eq 'matrix') {
        my $p = $t->{params};
        @matrix = (
            [ $p->[0], $p->[2],  $p->[4], ],
            [ $p->[1], $p->[3],  $p->[5], ],
            [ 0,       0,        1, ],
        );
    }
    return Math::Matrix->new(@matrix);
}

1;
