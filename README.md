# lib-audio-pulseaudio

Interface to the PulseAudio pulse-simple library.

## Dependencies

You'll need the [pulse-simple library](http://www.pulseaudio.org/).

On Ubuntu distributions;

    sudo apt install libpulse-dev

## Installation

    perl Makefile.PL
    make test
    sudo make install

## Example

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

## Methods

### new()

Instantiates a new Nick::Audio::PulseAudio object.

Arguments are interpreted as a hash and all are optional.

- device

    PulseAudio device name (e.g. alsa\_output.pci-0000\_00\_1f.3.analog-stereo)

    If unset, the default device will be used.

    Default: **unset**

- sample\_rate

    Sample rate of PCM data in **buffer\_in**.

    Default: **44100**

- channels

    Number of audio channels in PCM data in **buffer\_in**.

    Default: **2**

- buffer\_in

    Scalar that'll be used to pull/ push PCM data from/ to.

- buffer\_secs

    How many seconds of audio PulseAudio should buffer.

    Default: **1**

- server

    Hostname for PulseAudio server. Leave blank for localhost.

    Default: **unset**

- name

    Descriptive name for this client.

    Default: **NickAudio**

- app

    Descriptive name for this stream.

    Default: **Default**

- volume

    Volume the client should be play at.

    Value should be a percentage integer,

    If unset, the default volume will be set.

- read\_secs

    Greater than 0 if we'll be recording audio, and how many seconds of audio is read each time **read()** is called.

    Default: **unset**

### play()

Sends PCM audio data from **buffer\_in** to PulseAudio.

Blocks until audio is written to the server.

### play\_nb()

Sends PCM audio data from **buffer\_in** to PulseAudio.

Returns immediately.

### flush()

Blocks while PulseAudio is drained of audio.

### can\_write()

Returns the number of bytes that can be written to PulseAudio.

### set\_volume()

Volume the client should be play at.

Value should be a percentage integer.

### read()

Reads **read\_secs** seconds of PCM audio data from PulseAudio into **buffer\_in**.

Blocks until audio is retrieved to the server.
