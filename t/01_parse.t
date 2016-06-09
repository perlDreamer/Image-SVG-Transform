use strict;
use warnings;
use Test::More;
use Test::Exception;

use blib;

use_ok 'Image::SVG::Transform';

my $trans = Image::SVG::Transform->new(transform => 'scale(1)');
lives_ok { $trans->extract_transforms() } 'parses a single scale command';
is_deeply $trans->transforms(), [ { type => 'scale', params => [1], }], 'Correctly parsed the scale command with one arg';

lives_ok { $trans->extract_transforms('scale(1 2)'); } 'parses a single scale command, two args';
is_deeply $trans->transforms(), [ { type => 'scale', params => [1,2], }], 'Correctly parsed the scale command with two args';

dies_ok { $trans->extract_transforms('scalx(1 2)'); } 'dies on bad transform type';
like $@, qr'^Unknown transform scalx', 'correct error message';
is_deeply $trans->transforms(), [ { type => 'scale', params => [1,2], }], 'Correctly parsed the scale command with two args';

dies_ok { $trans->extract_transforms('scale(1 2 3)'); } 'dies on too many arguments';
like $@, qr'^Too many parameters 3 for transform scale', 'correct error message';
is_deeply $trans->transforms(), [ { type => 'scale', params => [1,2], }], 'Correctly parsed the scale command with two args';

lives_ok { $trans->extract_transforms('translate(4)'); } 'parses a single translate command, one arg';
is_deeply $trans->transforms(), [ { type => 'translate', params => [4,], }], 'Correctly parsed the translate command with one arg';

lives_ok { $trans->extract_transforms('translate(4,8)'); } 'parses a single translate command, two args';
is_deeply $trans->transforms(), [ { type => 'translate', params => [4,8], }], 'Correctly parsed the translate command with two args';

lives_ok { $trans->extract_transforms('translate(4,8) scale(0.5)'); } 'parses translate and scale commands';
is_deeply $trans->transforms(), [ { type => 'translate', params => [4,8], }, { type => 'scale', 'params' => [0.5], }, ], 'Correctly parsed the translate command with two commands';

lives_ok { $trans->extract_transforms('translate(4,8), scale(0.5)'); } 'parses translate and scale commands, comma sp b/w commands';
is_deeply $trans->transforms(), [ { type => 'translate', params => [4,8], }, { type => 'scale', 'params' => [0.5], }, ], '... validate command data';

lives_ok { $trans->extract_transforms('translate(4,8) , scale(0.5)'); } 'parses translate and scale commands, sp comma sp b/w commands';
is_deeply $trans->transforms(), [ { type => 'translate', params => [4,8], }, { type => 'scale', 'params' => [0.5], }, ], '... validate command data';

SKIP: {
    skip 'Pending better parsing technology', 4;
    lives_ok { $trans->extract_transforms('translate(4, 8)'); } 'parses translate and scale commands, comma sp b/w args';
    is_deeply $trans->transforms(), [ { type => 'translate', params => [4,8], }, ], '... validate command data';

    lives_ok { $trans->extract_transforms('translate(4 , 8)'); } 'parses translate and scale commands, sp comma sp b/w args';
    is_deeply $trans->transforms(), [ { type => 'translate', params => [4,8], }, ], '... validate command data';
}

lives_ok { $trans->extract_transforms('translate(4-7)'); } 'parses translate and scale commands, sp comma sp b/w args';
is_deeply $trans->transforms(), [ { type => 'translate', params => [4,-7], }, ], '... validate command data';

done_testing();
