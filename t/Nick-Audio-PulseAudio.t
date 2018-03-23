use strict;
use warnings;

use Test::More tests => 2;

use Time::HiRes 'sleep';

use_ok( 'Nick::Audio::PulseAudio' );

my $sample_rate = 22050;
my $hz = 441;
my $duration = 2;

my $buff_in;
my $pulse = Nick::Audio::PulseAudio -> new(
    'sample_rate'   => $sample_rate,
    'channels'      => 1,
    'buffer_in'     => \$buff_in,
    'buffer_secs'   => .5,
    'name'          => 'NickAudioTest',
    'volume'        => 75
);

ok( defined( $pulse ), 'new()' );

# make a sine wave block of data
my $pi2 = 8 * atan2 1, 1;
my $steps = $sample_rate / $hz;
my( $audio_block, $i );
for ( $i = 0; $i < $steps; $i++ ) {
    $audio_block .= pack 's', 32767 * sin(
        ( $i / $sample_rate ) * $pi2 * $hz
    );
}
my $audio_len = length $audio_block;
$steps = ( $duration * $sample_rate * 2 ) / $audio_len;

for ( $i = 0; $i < $steps; $i++ ) {
    while (
        $pulse -> can_write() < $audio_len
    ) {
        sleep .1;
    }
    $buff_in = $audio_block;
    $pulse -> play_nb();
}
$pulse -> flush();
