use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Nick::Audio::PulseAudio',
    VERSION_FROM        => 'lib/Nick/Audio/PulseAudio.pm',
    AUTHOR              => 'Nick Peskett',
    LIBS                => [ '-lpulse-simple' ]
);
