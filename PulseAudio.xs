#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#include <pulse/simple.h>
#include <pulse/error.h>
#include <pulse/volume.h>
#include <pulse/stream.h>
#include <pulse/introspect.h>
#include <pulse/thread-mainloop.h>

struct nickaudiopulseaudio {
    pa_simple *pa;
    SV *scalar_in;
    int channels;
};

struct pa_simple {
    pa_threaded_mainloop *mainloop;
    pa_context *context;
    pa_stream *stream;
    pa_stream_direction_t direction;
    const void *read_data;
    size_t read_index, read_length;
    int operation_success;
};

typedef struct nickaudiopulseaudio NICKAUDIOPULSEAUDIO;

MODULE = Nick::Audio::PulseAudio  PACKAGE = Nick::Audio::PulseAudio

static NICKAUDIOPULSEAUDIO *
NICKAUDIOPULSEAUDIO::new_xs( sample_rate, channels, scalar_in, buffer_secs, device, server, name, app, record )
        int sample_rate;
        int channels;
        SV *scalar_in;
        float buffer_secs;
        const char *device;
        const char *server;
        const char *name;
        const char *app;
        bool record;
    CODE:
        pa_sample_spec ss;
        ss.format = PA_SAMPLE_S16LE;
        ss.rate = sample_rate;
        ss.channels = channels;
        Newxz( RETVAL, 1, NICKAUDIOPULSEAUDIO );
        size_t bytes_sec;
        if ( buffer_secs == -1 ) {
            bytes_sec = -1;
        } else {
            bytes_sec = sample_rate * channels * 2 * buffer_secs;
        }
        pa_buffer_attr buffer;
        buffer.maxlength = -1;
        buffer.tlength = bytes_sec;
        buffer.prebuf = -1;
        buffer.minreq = -1;
        buffer.fragsize = bytes_sec;
        int error;
        RETVAL -> pa = pa_simple_new(
            *server == 0 ? NULL : server,
            name,
            record ? PA_STREAM_RECORD : PA_STREAM_PLAYBACK,
            *device == 0 ? NULL : device,
            app,
            &ss,
            NULL,
            &buffer,
            &error
        );
        if ( ! RETVAL -> pa ) {
            croak( "PulseAudio init failed: %s", pa_strerror( error ) );
        }
        RETVAL -> scalar_in = SvREFCNT_inc(
            SvROK( scalar_in )
            ? SvRV( scalar_in )
            : scalar_in
        );
        RETVAL -> channels = channels;
    OUTPUT:
        RETVAL

void
NICKAUDIOPULSEAUDIO::DESTROY()
    CODE:
        pa_simple_free( THIS -> pa );
        SvREFCNT_dec( THIS -> scalar_in );
        Safefree( THIS );

void
NICKAUDIOPULSEAUDIO::play()
    CODE:
        if (
            ! SvOK( THIS -> scalar_in )
        ) {
            XSRETURN_UNDEF;
        }
        STRLEN len_in;
        short int *in_buff = (short int*)SvPV( THIS -> scalar_in, len_in );
        int error;
        if (
            pa_simple_write(
                THIS -> pa,
                in_buff,
                len_in,
                &error
            ) < 0
        ) {
            croak( "PulseAudio play failed: %s", pa_strerror( error ) );
        }

void
NICKAUDIOPULSEAUDIO::play_nb()
    CODE:
        if (
            ! SvOK( THIS -> scalar_in )
        ) {
            XSRETURN_UNDEF;
        }
        pa_simple *pa = THIS -> pa;
        STRLEN len_in;
        short int *in_buff = (short int*)SvPV( THIS -> scalar_in, len_in );
        pa_threaded_mainloop_lock(
            pa -> mainloop
        );
        int ret = pa_stream_write(
            pa -> stream,
            in_buff,
            len_in,
            NULL,
            0,
            PA_SEEK_RELATIVE
        );
        pa_threaded_mainloop_unlock(
            pa -> mainloop
        );
        if ( ret != 0 ) {
            croak(
                "Unable play audio: %s",
                pa_strerror(
                    pa_context_errno(
                        pa -> context
                    )
                )
            );
        }

void
NICKAUDIOPULSEAUDIO::flush()
    CODE:
        int error;
        if (
            pa_simple_drain(
                THIS -> pa,
                &error
            ) < 0
        ) {
            croak( "PulseAudio flush failed: %s", pa_strerror( error ) );
        }

void
NICKAUDIOPULSEAUDIO::set_volume_xs( volume )
        int volume;
    CODE:
        pa_simple *pa = THIS -> pa;
        pa_cvolume cvol;
        cvol.channels = THIS -> channels;
        pa_cvolume_set(
            &cvol,
            THIS -> channels,
            PA_VOLUME_NORM * volume / 100
        );
        pa_threaded_mainloop_lock(
            pa -> mainloop
        );
        pa_operation *pa_o;
        pa_o = pa_context_set_sink_input_volume(
            pa -> context,
            pa_stream_get_index( pa -> stream ),
            &cvol,
            NULL,
            NULL
        );
        pa_threaded_mainloop_unlock(
            pa -> mainloop
        );
        if ( ! pa_o ) {
            croak(
                "Unable to set volume %d: %s",
                volume, pa_strerror(
                    pa_context_errno(
                        pa -> context
                    )
                )
            );
        }

size_t
NICKAUDIOPULSEAUDIO::can_write()
    CODE:
        RETVAL = pa_stream_writable_size( THIS -> pa -> stream );
    OUTPUT:
        RETVAL

void
NICKAUDIOPULSEAUDIO::read()
    CODE:
        STRLEN len_in;
        short int *in_buff = (short int*)SvPV( THIS -> scalar_in, len_in );
        int error;
        if (
            pa_simple_read(
                THIS -> pa,
                in_buff,
                len_in,
                &error
            ) < 0
        ) {
            croak( "PulseAudio read failed: %s", pa_strerror( error ) );
        }
