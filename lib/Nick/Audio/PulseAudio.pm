package Nick::Audio::PulseAudio;

use strict;
use warnings;

use XSLoader;
use Carp;

our( $VERSION, %DEFAULTS );

BEGIN {
    $VERSION = '0.01';
    XSLoader::load 'Nick::Audio::PulseAudio' => $VERSION;
    %DEFAULTS = (
        'sample_rate'   => 44100,
        'channels'      => 2,
        'buffer_in'     => do{ my $x = '' },
        'buffer_secs'   => 1,
        'device'        => '',
        'server'        => '',
        'name'          => 'NickAudio',
        'app'           => 'Default'
    );
}

=pod

=head1 NAME

Nick::Audio::PulseAudio - Interface to the pulse-simple library.

=head1 SYNOPSIS

Playing audio;

    use Nick::Audio::PulseAudio;
    use Time::HiRes 'sleep';

    my $sample_rate = 22050;
    my $hz = 441;
    my $duration = 7;

    my $buff_in;
    my $pulse = Nick::Audio::PulseAudio -> new(
        'sample_rate'   => $sample_rate,
        'channels'      => 1,
        'buffer_in'     => \$buff_in,
        'buffer_secs'   => .5,
        'name'          => 'NickAudioTest',
        'volume'        => 75
    );

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

Recording audio;

    use Nick::Audio::PulseAudio;
    use Nick::Audio::Wav::Write '$WAV_BUFFER';

    my $sample_rate = 44100;
    my $channels = 2;

    my $buffer;
    my $pulse = Nick::Audio::PulseAudio -> new(
        'sample_rate'   => $sample_rate,
        'channels'      => $channels,
        'buffer_in'     => \$WAV_BUFFER,
        'name'          => 'RecTest',
        'read_secs'     => .1
    );

    my $wav = Nick::Audio::Wav::Write -> new(
        '/tmp/test.wav',
        'channels' => $channels,
        'sample_rate' => $sample_rate,
        'bits_sample' => 16
    );

    my $i = 0;
    while ( $i++ < 100  ) {
        $pulse -> read();
        $wav -> write();
    }
    $wav -> close();

=head1 METHODS

=head2 new()

Instantiates a new Nick::Audio::PulseAudio object.

Arguments are interpreted as a hash and all are optional.

=over 2

=item device

PulseAudio device name (e.g. alsa_output.pci-0000_00_1f.3.analog-stereo)

If unset, the default device will be used.

Default: B<unset>

=item sample_rate

Sample rate of PCM data in B<buffer_in>.

Default: B<44100>

=item channels

Number of audio channels in PCM data in B<buffer_in>.

Default: B<2>

=item buffer_in

Scalar that'll be used to pull/ push PCM data from/ to.

=item buffer_secs

How many seconds of audio PulseAudio should buffer.

Default: B<1>

=item server

Hostname for PulseAudio server. Leave blank for localhost.

Default: B<unset>

=item name

Descriptive name for this client.

Default: B<NickAudio>

=item app

Descriptive name for this stream.

Default: B<Default>

=item volume

Volume the client should be play at.

Value should be a percentage integer,

If unset, the default volume will be set.

=item read_secs

Greater than 0 if we'll be recording audio, and how many seconds of audio is read each time B<read()> is called.

Default: B<unset>

=back

=head2 play()

Sends PCM audio data from B<buffer_in> to PulseAudio.

Blocks until audio is written to the server.

=head2 play_nb()

Sends PCM audio data from B<buffer_in> to PulseAudio.

Returns immediately.

=head2 flush()

Blocks while PulseAudio is drained of audio.

=head2 can_write()

Returns the number of bytes that can be written to PulseAudio.

=head2 set_volume()

Volume the client should be play at.

Value should be a percentage integer,

=head2 read()

Reads B<read_secs> seconds of PCM audio data from PulseAudio into B<buffer_in>.

Blocks until audio is retrieved to the server.

=cut

sub new {
    my( $class, %settings ) = @_;
    my @set = map(
        exists( $settings{$_} )
        ? $settings{$_}
        : $DEFAULTS{$_},
        qw(
            sample_rate channels buffer_in buffer_secs
            device server name app
        )
    );
    if (
        exists( $settings{'read_secs'} )
        && $settings{'read_secs'} > 0
    ) {
        my $bytes = $settings{'read_secs'}
                    * $settings{'sample_rate'}
                    * $settings{'channels'}
                    * 2;
        ${ $settings{'buffer_in'} } = pack 'c' . $bytes, 0;
        push @set => 1;
    } else {
        push @set => 0;
    }
    my $self = Nick::Audio::PulseAudio -> new_xs( @set );
    exists( $settings{'volume'} )
        && $settings{'volume'}
            and $self -> set_volume_xs( $settings{'volume'} );
    return $self;
}

sub set_volume {
    $_[0] -> flush();
    $_[0] -> set_volume_xs( $_[1] );
}

1;
