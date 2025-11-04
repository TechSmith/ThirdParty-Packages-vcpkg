cmake_minimum_required(VERSION 3.14)
project(soundpipe VERSION 1.7.0 LANGUAGES C)

# All modules (excluding those that need libsndfile: diskin, wavout, wavin, lpc)
set(MODULE_SOURCES
    modules/base.c modules/ftbl.c modules/tevent.c modules/adsr.c modules/allpass.c
    modules/atone.c modules/autowah.c modules/bal.c modules/bar.c modules/biquad.c
    modules/biscale.c modules/blsaw.c modules/blsquare.c modules/bltriangle.c modules/fold.c
    modules/bitcrush.c modules/brown.c modules/butbp.c modules/butbr.c modules/buthp.c
    modules/butlp.c modules/clip.c modules/clock.c modules/comb.c modules/compressor.c
    modules/count.c modules/conv.c modules/crossfade.c modules/dcblock.c modules/delay.c
    modules/diode.c modules/dist.c modules/dmetro.c modules/drip.c modules/dtrig.c
    modules/dust.c modules/eqfil.c modules/expon.c modules/fof.c modules/fog.c
    modules/fofilt.c modules/foo.c modules/fosc.c modules/gbuzz.c modules/hilbert.c
    modules/in.c modules/incr.c modules/jcrev.c modules/jitter.c modules/line.c
    modules/lpf18.c modules/maygate.c modules/metro.c modules/mincer.c modules/mode.c
    modules/moogladder.c modules/noise.c modules/nsmp.c modules/osc.c modules/oscmorph.c
    modules/pan2.c modules/panst.c modules/pareq.c modules/paulstretch.c modules/pdhalf.c
    modules/peaklim.c modules/phaser.c modules/phasor.c modules/pinknoise.c modules/pitchamdf.c
    modules/pluck.c modules/port.c modules/posc3.c modules/progress.c modules/prop.c
    modules/pshift.c modules/ptrack.c modules/randh.c modules/randi.c modules/randmt.c
    modules/random.c modules/reverse.c modules/reson.c modules/revsc.c modules/rms.c
    modules/rpt.c modules/rspline.c modules/saturator.c modules/samphold.c modules/scale.c
    modules/scrambler.c modules/sdelay.c modules/slice.c modules/smoothdelay.c modules/spa.c
    modules/sparec.c modules/streson.c modules/switch.c modules/tabread.c modules/tadsr.c
    modules/talkbox.c modules/tblrec.c modules/tbvcf.c modules/tdiv.c modules/tenv.c
    modules/tenv2.c modules/tenvx.c modules/tgate.c modules/thresh.c modules/timer.c
    modules/tin.c modules/tone.c modules/trand.c modules/tseg.c modules/tseq.c
    modules/vdelay.c modules/voc.c modules/vocoder.c modules/waveset.c modules/wpkorg35.c
    modules/zitarev.c modules/fftwrapper.c modules/padsynth.c
)

# Library sources
set(LIB_SOURCES
    lib/inih/ini.c
    lib/fft/fftlib.c
    lib/kissfft/kiss_fft.c
    lib/kissfft/kiss_fftr.c
    lib/spa/spa.c
    lib/dr_wav/dr_wav.c
)

add_library(soundpipe STATIC ${MODULE_SOURCES} ${LIB_SOURCES})

target_include_directories(soundpipe PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/h>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/lib/inih>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/lib/faust>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/lib/fft>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/lib/kissfft>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/lib/spa>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/lib/openlpc>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/lib/dr_wav>
    $<INSTALL_INTERFACE:include>
)

target_compile_definitions(soundpipe PRIVATE
    SP_VERSION=1.7.0
    NO_LIBSNDFILE
)

# Standard C99 (works on GCC, Clang, Emscripten)
set_target_properties(soundpipe PROPERTIES
    C_STANDARD 99
    C_STANDARD_REQUIRED ON
)

install(TARGETS soundpipe
    EXPORT soundpipe-targets
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
)

install(FILES h/soundpipe.h
    DESTINATION include
)

install(EXPORT soundpipe-targets
    FILE soundpipe-config.cmake
    NAMESPACE soundpipe::
    DESTINATION lib/cmake/soundpipe
)
