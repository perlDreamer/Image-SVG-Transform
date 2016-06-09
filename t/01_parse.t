use strict;
use warnings;
use Test::More;
use Test::Exception;

use blib;

use_ok 'Image::SVG::Transform';

my $trans = Image::SVG::Transform->new(transform => 'scale(1)');

lives_ok { $trans->extract_transforms() } 'parses a single scale command';

is_deeply $trans->transforms(), [ { type => 'scale', params => [1], }], 'Correctly parsed the scale command with one arg';

done_testing();
