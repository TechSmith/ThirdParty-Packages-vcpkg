vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ffmpeg/ffmpeg
    REF "n${VERSION}"
    SHA512 6b9a5ee501be41d6abc7579a106263b31f787321cbc45dedee97abf992bf8236cdb2394571dd256a74154f4a20018d429ae7e7f0409611ddc4d6f529d924d175
    HEAD_REF master
    PATCHES
        0001-create-lib-libraries.patch
        0002-fix-msvc-link.patch
        0003-fix-windowsinclude.patch
        0004-dependencies.patch
        0005-fix-nasm.patch
        0007-fix-lib-naming.patch
        0013-define-WINVER.patch
        0020-fix-aarch64-libswscale.patch
        0024-fix-osx-host-c11.patch
        0040-ffmpeg-add-av_stream_get_first_dts-for-chromium.patch # Do not remove this patch. It is required by chromium
        0041-add-const-for-opengl-definition.patch
        0043-fix-miss-head.patch
        1001-tsc-disable-aac-non-lc-profiles.patch
)

if(SOURCE_PATH MATCHES " ")
    message(FATAL_ERROR "Error: ffmpeg will not build with spaces in the path. Please use a directory with no spaces")
endif()

if (VCPKG_TARGET_ARCHITECTURE STREQUAL "x86" OR VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    vcpkg_find_acquire_program(NASM)
    get_filename_component(NASM_EXE_PATH "${NASM}" DIRECTORY)
    vcpkg_add_to_path("${NASM_EXE_PATH}")
endif()

set(OPTIONS "--enable-pic --disable-doc --enable-debug --enable-runtime-cpudetect --disable-autodetect")

# <Additional custom TechSmith options>
# Just to be extra-safe, we will disable everything and explicitly enable only the things we need
# FFMPEG References:
# - Muxers and Demuxers (Formats): https://ffmpeg.org/ffmpeg-formats.html
# - Encoders and decoders (Codecs): https://www.ffmpeg.org/ffmpeg-codecs.html
# - HW Acceleration: https://trac.ffmpeg.org/wiki/HWAccelIntro
string(REPLACE " " ";" OPTIONS ${OPTIONS}) # Convert space-separate list into a cmake list
list(PREPEND OPTIONS --disable-everything) # Start with "everything" disabled, and build up from there (it disables these things: https://stackoverflow.com/questions/24849129/compile-ffmpeg-without-most-codecs)
list(APPEND OPTIONS --disable-securetransport) # To avoid AppStore rejection by disabling the use of private API SecIdentityCreate()
list(APPEND OPTIONS --enable-protocol=file) # Only enable file protocol

# STV-AV1 codec support
if("stv-av1" IN_LIST FEATURES)
    set(APPEND OPTIONS --enable-stv-av1)
endif()

# === Add extra options for emscripten builds ===
if(VCPKG_TARGET_IS_EMSCRIPTEN)
    # Remove some options that we don't want for the emscripten build
    list(REMOVE_ITEM OPTIONS
         --enable-debug
         --enable-runtime-cpudetect
    )
    list(APPEND OPTIONS
         --logfile=configure.log
         --prefix=${CURRENT_PACKAGES_DIR}
         --target-os=none
         --arch=wasm32
         --enable-cross-compile
         --disable-x86asm
         --disable-inline-asm
         --disable-stripping
         --enable-shared # guarantee dynamic linking
         --disable-static # guarantee dynamic linking
         --disable-programs
         --disable-debug
         --disable-runtime-cpudetect
         --disable-autodetect
         --disable-network
         --disable-parsers
         --disable-pthreads
         --nm=emnm
         --ar=emar
         --ranlib=emranlib
         --cc=emcc
         --cxx=em++
         --objcc=emcc
         --dep-cc=emcc
         --extra-cflags=-pthread
         --extra-cflags=-g0
         --extra-cflags=-O3
         --extra-ldflags=-sSIDE_MODULE=1
         --extra-ldflags=-sWASM_BIGINT
         --extra-ldflags=-pthread
         --extra-ldflags=-sINITIAL_MEMORY=33554432)
endif()

# === Add TSC options based on feature flags ===
function(add_configure_options_from_enabled_features possible_components_list feature_prefix build_flag_prefix)
    set(COMPONENT_NAMES "")
    if(DEFINED ${possible_components_list})
        set(COMPONENT_NAMES ${${possible_components_list}})
    else()
        message(DEBUG "add_configure_options_from_enabled_features: Base list variable '${possible_components_list}' not defined.")
    endif()

    set(ENABLED_COMPONENTS "")
    foreach(COMPONENT_NAME IN LISTS COMPONENT_NAMES)
        set(FEATURE_NAME "${feature_prefix}${COMPONENT_NAME}")
        string(REPLACE "_" "-" FEATURE_NAME "${FEATURE_NAME}") # vcpkg feature names must not have underscores, so we replace them with hyphens
        if(FEATURE_NAME IN_LIST FEATURES)
            list(APPEND ENABLED_COMPONENTS ${COMPONENT_NAME})
        endif()
    endforeach()

    if(ENABLED_COMPONENTS)
        list(REMOVE_DUPLICATES ENABLED_COMPONENTS)
    endif()

    set(LOCAL_OPTIONS ${OPTIONS})
    #message(STATUS ">> [in function] LOCAL_OPTIONS: ${LOCAL_OPTIONS}")
    SET(BUILD_COMPONENT_OPTIONS "")
    list(TRANSFORM ENABLED_COMPONENTS PREPEND ${build_flag_prefix} OUTPUT_VARIABLE BUILD_COMPONENT_OPTIONS)
    list(APPEND LOCAL_OPTIONS ${BUILD_COMPONENT_OPTIONS} PARENT_SCOPE)
    set(OPTIONS ${LOCAL_OPTIONS})
endfunction()

# ----- Decoders -----
SET(DECODER_NAMES
    aac                     argo                    escape124               libaribcaption          mss1                    qoi                     vb
    aac_at                  ass                     escape130               libcelt                 mss2                    qpeg                    vble
    aac_fixed               asv1                    evrc                    libcodec2               msvideo1                qtrle                   vbn
    aac_latm                asv2                    exr                     libdav1d                mszh                    r10k                    vc1
    aac_mediacodec          atrac1                  fastaudio               libdavs2                mts2                    r210                    vc1_cuvid
    aasc                    atrac3                  ffv1                    libfdk_aac              mv30                    ra_144                  vc1_mmal
    ac3                     atrac3al                ffvhuff                 libgsm                  mvc1                    ra_288                  vc1_qsv
    ac3_at                  atrac3p                 ffwavesynth             libgsm_ms               mvc2                    ralf                    vc1_v4l2m2m
    ac3_fixed               atrac3pal               fic                     libilbc                 mvdv                    rasc                    vc1image
    acelp_kelvin            atrac9                  fits                    libjxl                  mvha                    rawvideo                vcr1
    adpcm_4xm               aura                    flac                    liblc3                  mwsc                    realtext                vmdaudio
    adpcm_adx               aura2                   flashsv                 libopencore_amrnb       mxpeg                   rka                     vmdvideo
    adpcm_afc               av1                     flashsv2                libopencore_amrwb       nellymoser              rl2                     vmix
    adpcm_agm               av1_cuvid               flic                    libopenh264             notchlc                 roq                     vmnc
    adpcm_aica              av1_mediacodec          flv                     libopus                 nuv                     roq_dpcm                vnull
    adpcm_argo              av1_qsv                 fmvc                    librsvg                 on2avc                  rpza                    vorbis
    adpcm_ct                avrn                    fourxm                  libspeex                opus                    rscc                    vp3
    adpcm_dtk               avrp                    fraps                   libuavs3d               osq                     rtv1                    vp4
    adpcm_ea                avs                     frwu                    libvorbis               paf_audio               rv10                    vp5
    adpcm_ea_maxis_xa       avui                    ftr                     libvpx_vp8              paf_video               rv20                    vp6
    adpcm_ea_r1             bethsoftvid             g2m                     libvpx_vp9              pam                     rv30                    vp6a
    adpcm_ea_r2             bfi                     g723_1                  libxevd                 pbm                     rv40                    vp6f
    adpcm_ea_r3             bink                    g729                    libzvbi_teletext        pcm_alaw                s302m                   vp7
    adpcm_ea_xas            binkaudio_dct           gdv                     loco                    pcm_alaw_at             sami                    vp8
    adpcm_g722              binkaudio_rdft          gem                     lscr                    pcm_bluray              sanm                    vp8_cuvid
    adpcm_g726              bintext                 gif                     m101                    pcm_dvd                 sbc                     vp8_mediacodec
    adpcm_g726le            bitpacked               gremlin_dpcm            mace3                   pcm_f16le               scpr                    vp8_qsv
    adpcm_ima_acorn         bmp                     gsm                     mace6                   pcm_f24le               screenpresso            vp8_rkmpp
    adpcm_ima_alp           bmv_audio               gsm_ms                  magicyuv                pcm_f32be               sdx2_dpcm               vp8_v4l2m2m
    adpcm_ima_amv           bmv_video               gsm_ms_at               mdec                    pcm_f32le               sga                     vp9
    adpcm_ima_apc           bonk                    h261                    media100                pcm_f64be               sgi                     vp9_cuvid
    adpcm_ima_apm           brender_pix             h263                    metasound               pcm_f64le               sgirle                  vp9_mediacodec
    adpcm_ima_cunning       c93                     h263_v4l2m2m            microdvd                pcm_lxf                 sheervideo              vp9_qsv
    adpcm_ima_dat4          cavs                    h263i                   mimic                   pcm_mulaw               shorten                 vp9_rkmpp
    adpcm_ima_dk3           cbd2_dpcm               h263p                   misc4                   pcm_mulaw_at            simbiosis_imx           vp9_v4l2m2m
    adpcm_ima_dk4           ccaption                h264                    mjpeg                   pcm_s16be               sipr                    vplayer
    adpcm_ima_ea_eacs       cdgraphics              h264_cuvid              mjpeg_cuvid             pcm_s16be_planar        siren                   vqa
    adpcm_ima_ea_sead       cdtoons                 h264_mediacodec         mjpeg_qsv               pcm_s16le               smackaud                vqc
    adpcm_ima_iss           cdxl                    h264_mmal               mjpegb                  pcm_s16le_planar        smacker                 vvc
    adpcm_ima_moflex        cfhd                    h264_qsv                mlp                     pcm_s24be               smc                     vvc_qsv
    adpcm_ima_mtf           cinepak                 h264_rkmpp              mmvideo                 pcm_s24daud             smvjpeg                 wady_dpcm
    adpcm_ima_oki           clearvideo              h264_v4l2m2m            mobiclip                pcm_s24le               snow                    wavarc
    adpcm_ima_qt            cljr                    hap                     motionpixels            pcm_s24le_planar        sol_dpcm                wavpack
    adpcm_ima_qt_at         cllc                    hca                     movtext                 pcm_s32be               sonic                   wbmp
    adpcm_ima_rad           comfortnoise            hcom                    mp1                     pcm_s32le               sp5x                    wcmv
    adpcm_ima_smjpeg        cook                    hdr                     mp1_at                  pcm_s32le_planar        speedhq                 webp
    adpcm_ima_ssi           cpia                    hevc                    mp1float                pcm_s64be               speex                   webvtt
    adpcm_ima_wav           cri                     hevc_cuvid              mp2                     pcm_s64le               srgc                    wmalossless
    adpcm_ima_ws            cscd                    hevc_mediacodec         mp2_at                  pcm_s8                  srt                     wmapro
    adpcm_ms                cyuv                    hevc_qsv                mp2float                pcm_s8_planar           ssa                     wmav1
    adpcm_mtaf              dca                     hevc_rkmpp              mp3                     pcm_sga                 stl                     wmav2
    adpcm_psx               dds                     hevc_v4l2m2m            mp3_at                  pcm_u16be               subrip                  wmavoice
    adpcm_sbpro_2           derf_dpcm               hnm4_video              mp3_mediacodec          pcm_u16le               subviewer               wmv1
    adpcm_sbpro_3           dfa                     hq_hqa                  mp3adu                  pcm_u24be               subviewer1              wmv2
    adpcm_sbpro_4           dfpwm                   hqx                     mp3adufloat             pcm_u24le               sunrast                 wmv3
    adpcm_swf               dirac                   huffyuv                 mp3float                pcm_u32be               svq1                    wmv3image
    adpcm_thp               dnxhd                   hymt                    mp3on4                  pcm_u32le               svq3                    wnv1
    adpcm_thp_le            dolby_e                 iac                     mp3on4float             pcm_u8                  tak                     wrapped_avframe
    adpcm_vima              dpx                     idcin                   mpc7                    pcm_vidc                targa                   ws_snd1
    adpcm_xa                dsd_lsbf                idf                     mpc8                    pcx                     targa_y216              xan_dpcm
    adpcm_xmd               dsd_lsbf_planar         iff_ilbm                mpeg1_cuvid             pdv                     tdsc                    xan_wc3
    adpcm_yamaha            dsd_msbf                ilbc                    mpeg1_v4l2m2m           pfm                     text                    xan_wc4
    adpcm_zork              dsd_msbf_planar         ilbc_at                 mpeg1video              pgm                     theora                  xbin
    agm                     dsicinaudio             imc                     mpeg2_cuvid             pgmyuv                  thp                     xbm
    aic                     dsicinvideo             imm4                    mpeg2_mediacodec        pgssub                  tiertexseqvideo         xface
    alac                    dss_sp                  imm5                    mpeg2_mmal              pgx                     tiff                    xl
    alac_at                 dst                     indeo2                  mpeg2_qsv               phm                     tmv                     xma1
    alias_pix               dvaudio                 indeo3                  mpeg2_v4l2m2m           photocd                 truehd                  xma2
    als                     dvbsub                  indeo4                  mpeg2video              pictor                  truemotion1             xpm
    amr_nb_at               dvdsub                  indeo5                  mpeg4                   pixlet                  truemotion2             xsub
    amrnb                   dvvideo                 interplay_acm           mpeg4_cuvid             pjs                     truemotion2rt           xwd
    amrnb_mediacodec        dxa                     interplay_dpcm          mpeg4_mediacodec        png                     truespeech              y41p
    amrwb                   dxtory                  interplay_video         mpeg4_mmal              ppm                     tscc                    ylc
    amrwb_mediacodec        dxv                     ipu                     mpeg4_v4l2m2m           prores                  tscc2                   yop
    amv                     eac3                    jacosub                 mpegvideo               prosumer                tta                     yuv4
    anm                     eac3_at                 jpeg2000                mpl2                    psd                     twinvq                  zero12v
    ansi                    eacmv                   jpegls                  msa1                    ptx                     txd                     zerocodec
    anull                   eamad                   jv                      mscc                    qcelp                   ulti                    zlib
    apac                    eatgq                   kgv1                    msmpeg4v1               qdm2                    utvideo                 zmbv
    ape                     eatgv                   kmvc                    msmpeg4v2               qdm2_at                 v210
    apng                    eatqi                   lagarith                msmpeg4v3               qdmc                    v210x
    aptx                    eightbps                lead                    msnsiren                qdmc_at                 v308
    aptx_hd                 eightsvx_exp            libaom_av1              msp2                    qdraw                   v408
    arbc                    eightsvx_fib            libaribb24              msrle                   qoa                     v410
)
add_configure_options_from_enabled_features(DECODER_NAMES "decoder-" "--enable-decoder=")

# ----- Encoders -----
SET(ENCODER_NAMES
    a64multi                av1_vaapi               h264_v4l2m2m            libtheora               msvideo1                pcx                     truehd
    a64multi5               avrp                    h264_vaapi              libtwolame              nellymoser              pfm                     tta
    aac                     avui                    h264_videotoolbox       libvo_amrwbenc          opus                    pgm                     ttml
    aac_at                  bitpacked               h264_vulkan             libvorbis               pam                     pgmyuv                  utvideo
    aac_mf                  bmp                     hap                     libvpx_vp8              pbm                     phm                     v210
    ac3                     cfhd                    hdr                     libvpx_vp9              pcm_alaw                png                     v308
    ac3_fixed               cinepak                 hevc_amf                libvvenc                pcm_alaw_at             ppm                     v408
    ac3_mf                  cljr                    hevc_d3d12va            libwebp                 pcm_bluray              prores                  v410
    adpcm_adx               comfortnoise            hevc_mediacodec         libwebp_anim            pcm_dvd                 prores_aw               vbn
    adpcm_argo              dca                     hevc_mf                 libx262                 pcm_f32be               prores_ks               vc2
    adpcm_g722              dfpwm                   hevc_nvenc              libx264                 pcm_f32le               prores_videotoolbox     vnull
    adpcm_g726              dnxhd                   hevc_qsv                libx264rgb              pcm_f64be               qoi                     vorbis
    adpcm_g726le            dpx                     hevc_v4l2m2m            libx265                 pcm_f64le               qtrle                   vp8_mediacodec
    adpcm_ima_alp           dvbsub                  hevc_vaapi              libxavs                 pcm_mulaw               r10k                    vp8_v4l2m2m
    adpcm_ima_amv           dvdsub                  hevc_videotoolbox       libxavs2                pcm_mulaw_at            r210                    vp8_vaapi
    adpcm_ima_apm           dvvideo                 hevc_vulkan             libxeve                 pcm_s16be               ra_144                  vp9_mediacodec
    adpcm_ima_qt            dxv                     huffyuv                 libxvid                 pcm_s16be_planar        rawvideo                vp9_qsv
    adpcm_ima_ssi           eac3                    ilbc_at                 ljpeg                   pcm_s16le               roq                     vp9_vaapi
    adpcm_ima_wav           exr                     jpeg2000                magicyuv                pcm_s16le_planar        roq_dpcm                wavpack
    adpcm_ima_ws            ffv1                    jpegls                  mjpeg                   pcm_s24be               rpza                    wbmp
    adpcm_ms                ffvhuff                 libaom_av1              mjpeg_qsv               pcm_s24daud             rv10                    webvtt
    adpcm_swf               fits                    libcodec2               mjpeg_vaapi             pcm_s24le               rv20                    wmav1
    adpcm_yamaha            flac                    libfdk_aac              mlp                     pcm_s24le_planar        s302m                   wmav2
    alac                    flashsv                 libgsm                  movtext                 pcm_s32be               sbc                     wmv1
    alac_at                 flashsv2                libgsm_ms               mp2                     pcm_s32le               sgi                     wmv2
    alias_pix               flv                     libilbc                 mp2fixed                pcm_s32le_planar        smc                     wrapped_avframe
    amv                     g723_1                  libjxl                  mp3_mf                  pcm_s64be               snow                    xbm
    anull                   gif                     libkvazaar              mpeg1video              pcm_s64le               sonic                   xface
    apng                    h261                    liblc3                  mpeg2_qsv               pcm_s8                  sonic_ls                xsub
    aptx                    h263                    libmp3lame              mpeg2_vaapi             pcm_s8_planar           speedhq                 xwd
    aptx_hd                 h263_v4l2m2m            libopencore_amrnb       mpeg2video              pcm_u16be               srt                     y41p
    ass                     h263p                   libopenh264             mpeg4                   pcm_u16le               ssa                     yuv4
    asv1                    h264_amf                libopenjpeg             mpeg4_mediacodec        pcm_u24be               subrip                  zlib
    asv2                    h264_mediacodec         libopus                 mpeg4_omx               pcm_u24le               sunrast                 zmbv
    av1_amf                 h264_mf                 librav1e                mpeg4_v4l2m2m           pcm_u32be               svq1
    av1_mediacodec          h264_nvenc              libshine                msmpeg4v2               pcm_u32le               targa
    av1_nvenc               h264_omx                libspeex                msmpeg4v3               pcm_u8                  text
    av1_qsv                 h264_qsv                libsvtav1               msrle                   pcm_vidc                tiff
)
add_configure_options_from_enabled_features(ENCODER_NAMES "encoder-" "--enable-encoder=")

# ----- Hardware accelerators (hwaccels) -----
SET(HWACCEL_NAMES
    av1_d3d11va             h264_d3d11va            hevc_d3d11va2           mpeg1_nvdec             mpeg2_videotoolbox      vc1_nvdec               vp9_vaapi
    av1_d3d11va2            h264_d3d11va2           hevc_d3d12va            mpeg1_vdpau             mpeg4_nvdec             vc1_vaapi               vp9_vdpau
    av1_d3d12va             h264_d3d12va            hevc_dxva2              mpeg1_videotoolbox      mpeg4_vaapi             vc1_vdpau               vp9_videotoolbox
    av1_dxva2               h264_dxva2              hevc_nvdec              mpeg2_d3d11va           mpeg4_vdpau             vp8_nvdec               wmv3_d3d11va
    av1_nvdec               h264_nvdec              hevc_vaapi              mpeg2_d3d11va2          mpeg4_videotoolbox      vp8_vaapi               wmv3_d3d11va2
    av1_vaapi               h264_vaapi              hevc_vdpau              mpeg2_d3d12va           prores_videotoolbox     vp9_d3d11va             wmv3_d3d12va
    av1_vdpau               h264_vdpau              hevc_videotoolbox       mpeg2_dxva2             vc1_d3d11va             vp9_d3d11va2            wmv3_dxva2
    av1_vulkan              h264_videotoolbox       hevc_vulkan             mpeg2_nvdec             vc1_d3d11va2            vp9_d3d12va             wmv3_nvdec
    h263_vaapi              h264_vulkan             mjpeg_nvdec             mpeg2_vaapi             vc1_d3d12va             vp9_dxva2               wmv3_vaapi
    h263_videotoolbox       hevc_d3d11va            mjpeg_vaapi             mpeg2_vdpau             vc1_dxva2               vp9_nvdec               wmv3_vdpau
)
add_configure_options_from_enabled_features(HWACCEL_NAMES "hwaccel-" "--enable-hwaccel=")

# ----- Demuxers -----
SET(DEMUXER_NAMES
    aa                      bmv                     g729                    image_sgi_pipe          mpc8                    pmp                     svs
    aac                     boa                     gdv                     image_sunrast_pipe      mpegps                  pp_bnk                  swf
    aax                     bonk                    genh                    image_svg_pipe          mpegts                  pva                     tak
    ac3                     brstm                   gif                     image_tiff_pipe         mpegtsraw               pvf                     tedcaptions
    ac4                     c93                     gsm                     image_vbn_pipe          mpegvideo               qcp                     thp
    ace                     caf                     gxf                     image_webp_pipe         mpjpeg                  qoa                     threedostr
    acm                     cavsvideo               h261                    image_xbm_pipe          mpl2                    r3d                     tiertexseq
    act                     cdg                     h263                    image_xpm_pipe          mpsub                   rawvideo                tmv
    adf                     cdxl                    h264                    image_xwd_pipe          msf                     rcwt                    truehd
    adp                     cine                    hca                     imf                     msnwc_tcp               realtext                tta
    ads                     codec2                  hcom                    ingenient               msp                     redspark                tty
    adx                     codec2raw               hevc                    ipmovie                 mtaf                    rka                     txd
    aea                     concat                  hls                     ipu                     mtv                     rl2                     ty
    afc                     dash                    hnm                     ircam                   musx                    rm                      usm
    aiff                    data                    iamf                    iss                     mv                      roq                     v210
    aix                     daud                    ico                     iv8                     mvi                     rpl                     v210x
    alp                     dcstr                   idcin                   ivf                     mxf                     rsd                     vag
    amr                     derf                    idf                     ivr                     mxg                     rso                     vapoursynth
    amrnb                   dfa                     iff                     jacosub                 nc                      rtp                     vc1
    amrwb                   dfpwm                   ifv                     jpegxl_anim             nistsphere              rtsp                    vc1t
    anm                     dhav                    ilbc                    jv                      nsp                     s337m                   vividas
    apac                    dirac                   image2                  kux                     nsv                     sami                    vivo
    apc                     dnxhd                   image2_alias_pix        kvag                    nut                     sap                     vmd
    ape                     dsf                     image2_brender_pix      laf                     nuv                     sbc                     vobsub
    apm                     dsicin                  image2pipe              lc3                     obu                     sbg                     voc
    apng                    dss                     image_bmp_pipe          libgme                  ogg                     scc                     vpk
    aptx                    dts                     image_cri_pipe          libmodplug              oma                     scd                     vplayer
    aptx_hd                 dtshd                   image_dds_pipe          libopenmpt              osq                     sdns                    vqf
    aqtitle                 dv                      image_dpx_pipe          live_flv                paf                     sdp                     vvc
    argo_asf                dvbsub                  image_exr_pipe          lmlm4                   pcm_alaw                sdr2                    w64
    argo_brp                dvbtxt                  image_gem_pipe          loas                    pcm_f32be               sds                     wady
    argo_cvg                dvdvideo                image_gif_pipe          lrc                     pcm_f32le               sdx                     wav
    asf                     dxa                     image_hdr_pipe          luodat                  pcm_f64be               segafilm                wavarc
    asf_o                   ea                      image_j2k_pipe          lvf                     pcm_f64le               ser                     wc3
    ass                     ea_cdata                image_jpeg_pipe         lxf                     pcm_mulaw               sga                     webm_dash_manifest
    ast                     eac3                    image_jpegls_pipe       m4v                     pcm_s16be               shorten                 webvtt
    au                      epaf                    image_jpegxl_pipe       matroska                pcm_s16le               siff                    wsaud
    av1                     evc                     image_pam_pipe          mca                     pcm_s24be               simbiosis_imx           wsd
    avi                     ffmetadata              image_pbm_pipe          mcc                     pcm_s24le               sln                     wsvqa
    avisynth                filmstrip               image_pcx_pipe          mgsts                   pcm_s32be               smacker                 wtv
    avr                     fits                    image_pfm_pipe          microdvd                pcm_s32le               smjpeg                  wv
    avs                     flac                    image_pgm_pipe          mjpeg                   pcm_s8                  smush                   wve
    avs2                    flic                    image_pgmyuv_pipe       mjpeg_2000              pcm_u16be               sol                     xa
    avs3                    flv                     image_pgx_pipe          mlp                     pcm_u16le               sox                     xbin
    bethsoftvid             fourxm                  image_phm_pipe          mlv                     pcm_u24be               spdif                   xmd
    bfi                     frm                     image_photocd_pipe      mm                      pcm_u24le               srt                     xmv
    bfstm                   fsb                     image_pictor_pipe       mmf                     pcm_u32be               stl                     xvag
    bink                    fwse                    image_png_pipe          mods                    pcm_u32le               str                     xwma
    binka                   g722                    image_ppm_pipe          moflex                  pcm_u8                  subviewer               yop
    bintext                 g723_1                  image_psd_pipe          mov                     pcm_vidc                subviewer1              yuv4mpegpipe
    bit                     g726                    image_qdraw_pipe        mp3                     pdv                     sup
    bitpacked               g726le                  image_qoi_pipe          mpc                     pjs                     svag
)
add_configure_options_from_enabled_features(DEMUXER_NAMES "demuxer-" "--enable-demuxer=")

# ----- Muxers -----
SET(MUXER_NAMES
    a64                     bit                     framemd5                latm                    mxf_d10                 pcm_u24le               streamhash
    ac3                     caf                     g722                    lc3                     mxf_opatom              pcm_u32be               sup
    ac4                     cavsvideo               g723_1                  lrc                     null                    pcm_u32le               swf
    adts                    chromaprint             g726                    m4v                     nut                     pcm_u8                  tee
    adx                     codec2                  g726le                  matroska                obu                     pcm_vidc                tg2
    aea                     codec2raw               gif                     matroska_audio          oga                     psp                     tgp
    aiff                    crc                     gsm                     md5                     ogg                     rawvideo                truehd
    alp                     dash                    gxf                     microdvd                ogv                     rcwt                    tta
    amr                     data                    h261                    mjpeg                   oma                     rm                      ttml
    amv                     daud                    h263                    mkvtimestamp_v2         opus                    roq                     uncodedframecrc
    apm                     dfpwm                   h264                    mlp                     pcm_alaw                rso                     vc1
    apng                    dirac                   hash                    mmf                     pcm_f32be               rtp                     vc1t
    aptx                    dnxhd                   hds                     mov                     pcm_f32le               rtp_mpegts              voc
    aptx_hd                 dts                     hevc                    mp2                     pcm_f64be               rtsp                    vvc
    argo_asf                dv                      hls                     mp3                     pcm_f64le               sap                     w64
    argo_cvg                eac3                    iamf                    mp4                     pcm_mulaw               sbc                     wav
    asf                     evc                     ico                     mpeg1system             pcm_s16be               scc                     webm
    asf_stream              f4v                     ilbc                    mpeg1vcd                pcm_s16le               segafilm                webm_chunk
    ass                     ffmetadata              image2                  mpeg1video              pcm_s24be               segment                 webm_dash_manifest
    ast                     fifo                    image2pipe              mpeg2dvd                pcm_s24le               smjpeg                  webp
    au                      filmstrip               ipod                    mpeg2svcd               pcm_s32be               smoothstreaming         webvtt
    avi                     fits                    ircam                   mpeg2video              pcm_s32le               sox                     wsaud
    avif                    flac                    ismv                    mpeg2vob                pcm_s8                  spdif                   wtv
    avm2                    flv                     ivf                     mpegts                  pcm_u16be               spx                     wv
    avs2                    framecrc                jacosub                 mpjpeg                  pcm_u16le               srt                     yuv4mpegpipe
    avs3                    framehash               kvag                    mxf                     pcm_u24be               stream_segment
)
add_configure_options_from_enabled_features(MUXER_NAMES "muxer-" "--enable-muxer=")

# ----- Parsers -----
SET(PARSER_NAMES
    aac                     cavsvideo               dvbsub                  gsm                     misc4                   qoi                     vp9
    aac_latm                cook                    dvd_nav                 h261                    mjpeg                   rv34                    vvc
    ac3                     cri                     dvdsub                  h263                    mlp                     sbc                     webp
    adx                     dca                     evc                     h264                    mpeg4video              sipr                    xbm
    amr                     dirac                   flac                    hdr                     mpegaudio               tak                     xma
    av1                     dnxhd                   ftr                     hevc                    mpegvideo               vc1                     xwd
    avs2                    dolby_e                 g723_1                  ipu                     opus                    vorbis
    avs3                    dpx                     g729                    jpeg2000                png                     vp3
    bmp                     dvaudio                 gif                     jpegxl                  pnm                     vp8
)
add_configure_options_from_enabled_features(PARSER_NAMES "parser-" "--enable-parser=")

# ----- Protocols -----
SET(PROTOCOL_NAMES
    android_content         fd                      http                    librtmp                 libzmq                  rtmps                   tcp
    async                   ffrtmpcrypt             httpproxy               librtmpe                md5                     rtmpt                   tee
    bluray                  ffrtmphttp              https                   librtmps                mmsh                    rtmpte                  tls
    cache                   file                    icecast                 librtmpt                mmst                    rtmpts                  udp
    concat                  ftp                     ipfs_gateway            librtmpte               pipe                    rtp                     udplite
    concatf                 gopher                  ipns_gateway            libsmbclient            prompeg                 sctp                    unix
    crypto                  gophers                 libamqp                 libsrt                  rtmp                    srtp
    data                    hls                     librist                 libssh                  rtmpe                   subfile
)
add_configure_options_from_enabled_features(PROTOCOL_NAMES "protocol-" "--enable-protocol=")

# ----- Bitstream filters (bsfs) -----
SET(BSFS_NAMES
    aac_adtstoasc           dts2pts                 h264_metadata           media100_to_mjpegb      null                    showinfo                vp9_superframe_split
    av1_frame_merge         dump_extradata          h264_mp4toannexb        mjpeg2jpeg              opus_metadata           text2movsub             vvc_metadata
    av1_frame_split         dv_error_marker         h264_redundant_pps      mjpega_dump_header      pcm_rechunk             trace_headers           vvc_mp4toannexb
    av1_metadata            eac3_core               hapqa_extract           mov2textsub             pgs_frame_merge         truehd_core
    chomp                   evc_frame_merge         hevc_metadata           mpeg2_metadata          prores_metadata         vp9_metadata
    dca_core                extract_extradata       hevc_mp4toannexb        mpeg4_unpack_bframes    remove_extradata        vp9_raw_reorder
    dovi_rpu                filter_units            imx_dump_header         noise                   setts                   vp9_superframe
)
add_configure_options_from_enabled_features(BSFS_NAMES "bsfs-" "--enable-bsfs=")

# ----- Input devices (indevs) -----
SET(INDEV_NAMES
    alsa                    bktr                    fbdev                   jack                    libcdio                 oss                     v4l2
    android_camera          decklink                gdigrab                 kmsgrab                 libdc1394               pulse                   vfwcap
    avfoundation            dshow                   iec61883                lavfi                   openal                  sndio                   xcbgrab
)
add_configure_options_from_enabled_features(INDEV_NAMES "indev-" "--enable-indev=")

# ----- Output devices (outdevs) -----
SET(OUTDEV_NAMES
    alsa                    caca                    fbdev                   oss                     sdl2                    v4l2
    audiotoolbox            decklink                opengl                  pulse                   sndio                   xv
)
add_configure_options_from_enabled_features(OUTDEV_NAMES "outdev-" "--enable-outdev=")

# ----- Filters -----
SET(FILTER_NAMES
    a3dscope                asetpts                 colortemperature        flite                   mandelbrot              repeatfields            swaprect
    aap                     asetrate                compand                 floodfill               maskedclamp             replaygain              swapuv
    abench                  asettb                  compensationdelay       format                  maskedmax               reverse                 tblend
    abitscope               ashowinfo               concat                  fps                     maskedmerge             rgbashift               telecine
    acompressor             asidedata               convolution             framepack               maskedmin               rgbtestsrc              testsrc
    acontrast               asisdr                  convolution_opencl      framerate               maskedthreshold         roberts                 testsrc2
    acopy                   asoftclip               convolve                framestep               maskfun                 roberts_opencl          thistogram
    acrossfade              aspectralstats          copy                    freezedetect            mcdeint                 rotate                  threshold
    acrossover              asplit                  coreimage               freezeframes            mcompand                rubberband              thumbnail
    acrusher                asr                     coreimagesrc            frei0r                  median                  sab                     thumbnail_cuda
    acue                    ass                     corr                    frei0r_src              mergeplanes             scale                   tile
    addroi                  astats                  cover_rect              fspp                    mestimate               scale2ref               tiltandshift
    adeclick                astreamselect           crop                    fsync                   metadata                scale2ref_npp           tiltshelf
    adeclip                 asubboost               cropdetect              gblur                   midequalizer            scale_cuda              tinterlace
    adecorrelate            asubcut                 crossfeed               gblur_vulkan            minterpolate            scale_npp               tlut2
    adelay                  asupercut               crystalizer             geq                     mix                     scale_qsv               tmedian
    adenorm                 asuperpass              cue                     gradfun                 monochrome              scale_vaapi             tmidequalizer
    aderivative             asuperstop              curves                  gradients               morpho                  scale_vt                tmix
    adrawgraph              atadenoise              datascope               graphmonitor            movie                   scale_vulkan            tonemap
    adrc                    atempo                  dblur                   grayworld               mpdecimate              scdet                   tonemap_opencl
    adynamicequalizer       atilt                   dcshift                 greyedge                mptestsrc               scharr                  tonemap_vaapi
    adynamicsmooth          atrim                   dctdnoiz                guided                  msad                    scroll                  tpad
    aecho                   avectorscope            ddagrab                 haas                    multiply                segment                 transpose
    aemphasis               avgblur                 deband                  haldclut                negate                  select                  transpose_npp
    aeval                   avgblur_opencl          deblock                 haldclutsrc             nlmeans                 selectivecolor          transpose_opencl
    aevalsrc                avgblur_vulkan          decimate                hdcd                    nlmeans_opencl          sendcmd                 transpose_vaapi
    aexciter                avsynctest              deconvolve              headphone               nlmeans_vulkan          separatefields          transpose_vt
    afade                   axcorrelate             dedot                   hflip                   nnedi                   setdar                  transpose_vulkan
    afdelaysrc              azmq                    deesser                 hflip_vulkan            noformat                setfield                treble
    afftdn                  backgroundkey           deflate                 highpass                noise                   setparams               tremolo
    afftfilt                bandpass                deflicker               highshelf               normalize               setpts                  trim
    afir                    bandreject              deinterlace_qsv         hilbert                 null                    setrange                unpremultiply
    afireqsrc               bass                    deinterlace_vaapi       histeq                  nullsink                setsar                  unsharp
    afirsrc                 bbox                    dejudder                histogram               nullsrc                 settb                   unsharp_opencl
    aformat                 bench                   delogo                  hqdn3d                  ocr                     sharpen_npp             untile
    afreqshift              bilateral               denoise_vaapi           hqx                     ocv                     sharpness_vaapi         uspp
    afwtdn                  bilateral_cuda          derain                  hstack                  openclsrc               shear                   v360
    agate                   biquad                  deshake                 hstack_qsv              oscilloscope            showcqt                 vaguedenoiser
    agraphmonitor           bitplanenoise           deshake_opencl          hstack_vaapi            overlay                 showcwt                 varblur
    ahistogram              blackdetect             despill                 hsvhold                 overlay_cuda            showfreqs               vectorscope
    aiir                    blackframe              detelecine              hsvkey                  overlay_opencl          showinfo                vflip
    aintegral               blend                   dialoguenhance          hue                     overlay_qsv             showpalette             vflip_vulkan
    ainterleave             blend_vulkan            dilation                huesaturation           overlay_vaapi           showspatial             vfrdet
    alatency                blockdetect             dilation_opencl         hwdownload              overlay_vulkan          showspectrum            vibrance
    alimiter                blurdetect              displace                hwmap                   owdenoise               showspectrumpic         vibrato
    allpass                 bm3d                    dnn_classify            hwupload                pad                     showvolume              vidstabdetect
    allrgb                  boxblur                 dnn_detect              hwupload_cuda           pad_opencl              showwaves               vidstabtransform
    allyuv                  boxblur_opencl          dnn_processing          hysteresis              pad_vaapi               showwavespic            vif
    aloop                   bs2b                    doubleweave             iccdetect               pal100bars              shuffleframes           vignette
    alphaextract            bwdif                   drawbox                 iccgen                  pal75bars               shufflepixels           virtualbass
    alphamerge              bwdif_cuda              drawbox_vaapi           identity                palettegen              shuffleplanes           vmafmotion
    amerge                  bwdif_vulkan            drawgraph               idet                    paletteuse              sidechaincompress       volume
    ametadata               cas                     drawgrid                il                      pan                     sidechaingate           volumedetect
    amix                    ccrepack                drawtext                inflate                 perlin                  sidedata                vpp_qsv
    amovie                  cellauto                drmeter                 interlace               perms                   sierpinski              vstack
    amplify                 channelmap              dynaudnorm              interleave              perspective             signalstats             vstack_qsv
    amultiply               channelsplit            earwax                  join                    phase                   signature               vstack_vaapi
    anequalizer             chorus                  ebur128                 kerndeint               photosensitivity        silencedetect           w3fdif
    anlmdn                  chromaber_vulkan        edgedetect              kirsch                  pixdesctest             silenceremove           waveform
    anlmf                   chromahold              elbg                    ladspa                  pixelize                sinc                    weave
    anlms                   chromakey               entropy                 lagfun                  pixscope                sine                    xbr
    anoisesrc               chromakey_cuda          epx                     latency                 pp                      siti                    xcorrelate
    anull                   chromanr                eq                      lcevc                   pp7                     smartblur               xfade
    anullsink               chromashift             equalizer               lenscorrection          premultiply             smptebars               xfade_opencl
    anullsrc                ciescope                erosion                 lensfun                 prewitt                 smptehdbars             xfade_vulkan
    apad                    codecview               erosion_opencl          libplacebo              prewitt_opencl          sobel                   xmedian
    aperms                  color                   estdif                  libvmaf                 procamp_vaapi           sobel_opencl            xpsnr
    aphasemeter             color_vulkan            exposure                libvmaf_cuda            program_opencl          sofalizer               xstack
    aphaser                 colorbalance            extractplanes           life                    pseudocolor             spectrumsynth           xstack_qsv
    aphaseshift             colorchannelmixer       extrastereo             limitdiff               psnr                    speechnorm              xstack_vaapi
    apsnr                   colorchart              fade                    limiter                 pullup                  split                   yadif
    apsyclip                colorcontrast           feedback                loop                    qp                      spp                     yadif_cuda
    apulsator               colorcorrect            fftdnoiz                loudnorm                qrencode                sr                      yadif_videotoolbox
    arealtime               colorhold               fftfilt                 lowpass                 qrencodesrc             ssim                    yaepblur
    aresample               colorize                field                   lowshelf                quirc                   ssim360                 yuvtestsrc
    areverse                colorkey                fieldhint               lumakey                 random                  stereo3d                zmq
    arls                    colorkey_opencl         fieldmatch              lut                     readeia608              stereotools             zoneplate
    arnndn                  colorlevels             fieldorder              lut1d                   readvitc                stereowiden             zoompan
    asdr                    colormap                fillborders             lut2                    realtime                streamselect            zscale
    asegment                colormatrix             find_rect               lut3d                   remap                   subtitles
    aselect                 colorspace              firequalizer            lutrgb                  remap_opencl            super2xsai
    asendcmd                colorspace_cuda         flanger                 lutyuv                  removegrain             superequalizer
    asetnsamples            colorspectrum           flip_vulkan             lv2                     removelogo              surround
)
add_configure_options_from_enabled_features(FILTER_NAMES "filter-" "--enable-filter=")

# === Run emscripten build (if applicable) ===
if(VCPKG_TARGET_IS_EMSCRIPTEN)

    # Patch the configure script to work with Emscripten
    set(ORIG_CONFIGURE ${SOURCE_PATH}/configure)
    file(READ "${ORIG_CONFIGURE}" FILE_CONTENTS)
    set(LINES_TO_COMMENT_OUT
       "check_ldflags -Wl,-z,noexecstack"
       "check_func  gethrtime"
       "check_func  sched_getaffinity"
       "check_func  sysctl"
    )
    foreach(LINE ${LINES_TO_COMMENT_OUT})
        string(REPLACE "${LINE}" "# Disabled for Emscripten build ${LINE}" FILE_CONTENTS "${FILE_CONTENTS}")
    endforeach()
    file(WRITE "${SOURCE_PATH}/configure" "${FILE_CONTENTS}")

endif()

# Convert OPTIONS back to a string
string(REPLACE ";" " " OPTIONS "${OPTIONS}")
# </Additional custom TechSmith options>

if(VCPKG_TARGET_IS_MINGW)
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        string(APPEND OPTIONS " --target-os=mingw32")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        string(APPEND OPTIONS " --target-os=mingw64")
    endif()
elseif(VCPKG_TARGET_IS_LINUX)
    string(APPEND OPTIONS " --target-os=linux --enable-pthreads")
elseif(VCPKG_TARGET_IS_UWP)
    string(APPEND OPTIONS " --target-os=win32 --enable-w32threads --enable-d3d11va --enable-d3d12va --enable-mediafoundation")
elseif(VCPKG_TARGET_IS_WINDOWS)
    string(APPEND OPTIONS " --target-os=win32 --enable-w32threads --enable-d3d11va --enable-d3d12va --enable-dxva2 --enable-mediafoundation")
elseif(VCPKG_TARGET_IS_OSX)
    string(APPEND OPTIONS " --target-os=darwin --enable-appkit --enable-avfoundation --enable-coreimage --enable-audiotoolbox --enable-videotoolbox")
elseif(VCPKG_TARGET_IS_IOS)
    string(APPEND OPTIONS " --enable-avfoundation --enable-coreimage --enable-videotoolbox")
elseif(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "Android")
    string(APPEND OPTIONS " --target-os=android --enable-jni --enable-mediacodec")
elseif(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "QNX")
    string(APPEND OPTIONS " --target-os=qnx")
endif()

if(VCPKG_TARGET_IS_OSX)
    list(JOIN VCPKG_OSX_ARCHITECTURES " " OSX_ARCHS)
    list(LENGTH VCPKG_OSX_ARCHITECTURES OSX_ARCH_COUNT)
endif()

vcpkg_cmake_get_vars(cmake_vars_file)
include("${cmake_vars_file}")
if(VCPKG_DETECTED_MSVC)
    string(APPEND OPTIONS " --disable-inline-asm") # clang-cl has inline assembly but this leads to undefined symbols.
    set(OPTIONS "--toolchain=msvc ${OPTIONS}")
    # This is required because ffmpeg depends upon optimizations to link correctly
    string(APPEND VCPKG_COMBINED_C_FLAGS_DEBUG " -O2")
    string(REGEX REPLACE "(^| )-RTC1( |$)" " " VCPKG_COMBINED_C_FLAGS_DEBUG "${VCPKG_COMBINED_C_FLAGS_DEBUG}")
    string(REGEX REPLACE "(^| )-Od( |$)" " " VCPKG_COMBINED_C_FLAGS_DEBUG "${VCPKG_COMBINED_C_FLAGS_DEBUG}")
    string(REGEX REPLACE "(^| )-Ob0( |$)" " " VCPKG_COMBINED_C_FLAGS_DEBUG "${VCPKG_COMBINED_C_FLAGS_DEBUG}")
endif()

string(APPEND VCPKG_COMBINED_C_FLAGS_DEBUG " -I \"${CURRENT_INSTALLED_DIR}/include\"")
string(APPEND VCPKG_COMBINED_C_FLAGS_RELEASE " -I \"${CURRENT_INSTALLED_DIR}/include\"")

## Setup vcpkg toolchain

set(prog_env "")

if(VCPKG_DETECTED_CMAKE_C_COMPILER)
    get_filename_component(CC_path "${VCPKG_DETECTED_CMAKE_C_COMPILER}" DIRECTORY)
    get_filename_component(CC_filename "${VCPKG_DETECTED_CMAKE_C_COMPILER}" NAME)
    set(ENV{CC} "${CC_filename}")
    string(APPEND OPTIONS " --cc=${CC_filename}")
    string(APPEND OPTIONS " --host_cc=${CC_filename}")
    list(APPEND prog_env "${CC_path}")
endif()

if(VCPKG_DETECTED_CMAKE_CXX_COMPILER)
    get_filename_component(CXX_path "${VCPKG_DETECTED_CMAKE_CXX_COMPILER}" DIRECTORY)
    get_filename_component(CXX_filename "${VCPKG_DETECTED_CMAKE_CXX_COMPILER}" NAME)
    set(ENV{CXX} "${CXX_filename}")
    string(APPEND OPTIONS " --cxx=${CXX_filename}")
    #string(APPEND OPTIONS " --host_cxx=${CC_filename}")
    list(APPEND prog_env "${CXX_path}")
endif()

if(VCPKG_DETECTED_CMAKE_RC_COMPILER)
    get_filename_component(RC_path "${VCPKG_DETECTED_CMAKE_RC_COMPILER}" DIRECTORY)
    get_filename_component(RC_filename "${VCPKG_DETECTED_CMAKE_RC_COMPILER}" NAME)
    set(ENV{WINDRES} "${RC_filename}")
    string(APPEND OPTIONS " --windres=${RC_filename}")
    list(APPEND prog_env "${RC_path}")
endif()

if(VCPKG_DETECTED_CMAKE_LINKER AND VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_TARGET_IS_MINGW)
    get_filename_component(LD_path "${VCPKG_DETECTED_CMAKE_LINKER}" DIRECTORY)
    get_filename_component(LD_filename "${VCPKG_DETECTED_CMAKE_LINKER}" NAME)
    set(ENV{LD} "${LD_filename}")
    string(APPEND OPTIONS " --ld=${LD_filename}")
    #string(APPEND OPTIONS " --host_ld=${LD_filename}")
    list(APPEND prog_env "${LD_path}")
endif()

if(VCPKG_DETECTED_CMAKE_NM)
    get_filename_component(NM_path "${VCPKG_DETECTED_CMAKE_NM}" DIRECTORY)
    get_filename_component(NM_filename "${VCPKG_DETECTED_CMAKE_NM}" NAME)
    set(ENV{NM} "${NM_filename}")
    string(APPEND OPTIONS " --nm=${NM_filename}")
    list(APPEND prog_env "${NM_path}")
endif()

if(VCPKG_DETECTED_CMAKE_AR)
    get_filename_component(AR_path "${VCPKG_DETECTED_CMAKE_AR}" DIRECTORY)
    get_filename_component(AR_filename "${VCPKG_DETECTED_CMAKE_AR}" NAME)
    if(AR_filename MATCHES [[^(llvm-)?lib\.exe$]])
        set(ENV{AR} "ar-lib ${AR_filename}")
        string(APPEND OPTIONS " --ar='ar-lib ${AR_filename}'")
    else()
        set(ENV{AR} "${AR_filename}")
        string(APPEND OPTIONS " --ar='${AR_filename}'")
    endif()
    list(APPEND prog_env "${AR_path}")
endif()

if(VCPKG_DETECTED_CMAKE_RANLIB)
    get_filename_component(RANLIB_path "${VCPKG_DETECTED_CMAKE_RANLIB}" DIRECTORY)
    get_filename_component(RANLIB_filename "${VCPKG_DETECTED_CMAKE_RANLIB}" NAME)
    set(ENV{RANLIB} "${RANLIB_filename}")
    string(APPEND OPTIONS " --ranlib=${RANLIB_filename}")
    list(APPEND prog_env "${RANLIB_path}")
endif()

if(VCPKG_DETECTED_CMAKE_STRIP)
    get_filename_component(STRIP_path "${VCPKG_DETECTED_CMAKE_STRIP}" DIRECTORY)
    get_filename_component(STRIP_filename "${VCPKG_DETECTED_CMAKE_STRIP}" NAME)
    set(ENV{STRIP} "${STRIP_filename}")
    string(APPEND OPTIONS " --strip=${STRIP_filename}")
    list(APPEND prog_env "${STRIP_path}")
endif()

if(VCPKG_HOST_IS_WINDOWS)
    vcpkg_acquire_msys(MSYS_ROOT PACKAGES automake)
    set(SHELL "${MSYS_ROOT}/usr/bin/bash.exe")
    vcpkg_execute_required_process(
        COMMAND "${SHELL}" -c "'/usr/bin/automake' --print-lib"
        OUTPUT_VARIABLE automake_lib
        OUTPUT_STRIP_TRAILING_WHITESPACE
        WORKING_DIRECTORY "${MSYS_ROOT}"
        LOGNAME automake-print-lib
    )
    list(APPEND prog_env "${MSYS_ROOT}/usr/bin" "${MSYS_ROOT}${automake_lib}")
else()
    find_program(SHELL bash)
endif()

list(REMOVE_DUPLICATES prog_env)
vcpkg_add_to_path(PREPEND ${prog_env})

# More? OBJCC BIN2C

file(REMOVE_RECURSE "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg" "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")

set(FFMPEG_PKGCONFIG_MODULES libavutil)

if("nonfree" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-nonfree")
endif()

if("gpl" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-gpl")
endif()

if("version3" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-version3")
endif()

if("ffmpeg" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-ffmpeg")
else()
    set(OPTIONS "${OPTIONS} --disable-ffmpeg")
endif()

if("ffplay" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-ffplay")
else()
    set(OPTIONS "${OPTIONS} --disable-ffplay")
endif()

if("ffprobe" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-ffprobe")
else()
    set(OPTIONS "${OPTIONS} --disable-ffprobe")
endif()

if("avcodec" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-avcodec")
    set(ENABLE_AVCODEC ON)
    list(APPEND FFMPEG_PKGCONFIG_MODULES libavcodec)
else()
    set(OPTIONS "${OPTIONS} --disable-avcodec")
    set(ENABLE_AVCODEC OFF)
endif()

if("avdevice" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-avdevice")
    set(ENABLE_AVDEVICE ON)
    list(APPEND FFMPEG_PKGCONFIG_MODULES libavdevice)
else()
    set(OPTIONS "${OPTIONS} --disable-avdevice")
    set(ENABLE_AVDEVICE OFF)
endif()

if("avformat" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-avformat")
    set(ENABLE_AVFORMAT ON)
    list(APPEND FFMPEG_PKGCONFIG_MODULES libavformat)
else()
    set(OPTIONS "${OPTIONS} --disable-avformat")
    set(ENABLE_AVFORMAT OFF)
endif()

if("avfilter" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-avfilter")
    set(ENABLE_AVFILTER ON)
    list(APPEND FFMPEG_PKGCONFIG_MODULES libavfilter)
else()
    set(OPTIONS "${OPTIONS} --disable-avfilter")
    set(ENABLE_AVFILTER OFF)
endif()

if("postproc" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-postproc")
    set(ENABLE_POSTPROC ON)
    list(APPEND FFMPEG_PKGCONFIG_MODULES libpostproc)
else()
    set(OPTIONS "${OPTIONS} --disable-postproc")
    set(ENABLE_POSTPROC OFF)
endif()

if("swresample" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-swresample")
    set(ENABLE_SWRESAMPLE ON)
    list(APPEND FFMPEG_PKGCONFIG_MODULES libswresample)
else()
    set(OPTIONS "${OPTIONS} --disable-swresample")
    set(ENABLE_SWRESAMPLE OFF)
endif()

if("swscale" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-swscale")
    set(ENABLE_SWSCALE ON)
    list(APPEND FFMPEG_PKGCONFIG_MODULES libswscale)
else()
    set(OPTIONS "${OPTIONS} --disable-swscale")
    set(ENABLE_SWSCALE OFF)
endif()

if ("alsa" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-alsa")
else()
    set(OPTIONS "${OPTIONS} --disable-alsa")
endif()

if("amf" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-amf")
else()
    set(OPTIONS "${OPTIONS} --disable-amf")
endif()

if("aom" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libaom")
    set(WITH_AOM ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libaom")
    set(WITH_AOM OFF)
endif()

if("ass" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libass")
    set(WITH_ASS ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libass")
    set(WITH_ASS OFF)
endif()

if("avisynthplus" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-avisynth")
else()
    set(OPTIONS "${OPTIONS} --disable-avisynth")
endif()

if("bzip2" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-bzlib")
else()
    set(OPTIONS "${OPTIONS} --disable-bzlib")
endif()

if("dav1d" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libdav1d")
    set(WITH_DAV1D ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libdav1d")
    set(WITH_DAV1D OFF)
endif()

if("fdk-aac" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libfdk-aac")
    set(WITH_AAC ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libfdk-aac")
    set(WITH_AAC OFF)
endif()

if("fontconfig" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libfontconfig")
else()
    set(OPTIONS "${OPTIONS} --disable-libfontconfig")
endif()

if("drawtext" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libharfbuzz")
else()
    set(OPTIONS "${OPTIONS} --disable-libharfbuzz")
endif()

if("freetype" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libfreetype")
else()
    set(OPTIONS "${OPTIONS} --disable-libfreetype")
endif()

if("fribidi" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libfribidi")
else()
    set(OPTIONS "${OPTIONS} --disable-libfribidi")
endif()

if("iconv" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-iconv")
    set(WITH_ICONV ON)
else()
    set(OPTIONS "${OPTIONS} --disable-iconv")
    set(WITH_ICONV OFF)
endif()

if("ilbc" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libilbc")
    set(WITH_ILBC ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libilbc")
    set(WITH_ILBC OFF)
endif()

if("lzma" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-lzma")
    set(WITH_LZMA ON)
else()
    set(OPTIONS "${OPTIONS} --disable-lzma")
    set(WITH_LZMA OFF)
endif()

if("mp3lame" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libmp3lame")
    set(WITH_MP3LAME ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libmp3lame")
    set(WITH_MP3LAME OFF)
endif()

if("modplug" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libmodplug")
    set(WITH_MODPLUG ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libmodplug")
    set(WITH_MODPLUG OFF)
endif()

if("nvcodec" IN_LIST FEATURES)
    #Note: the --enable-cuda option does not actually require the cuda sdk or toolset port dependency as ffmpeg uses runtime detection and dynamic loading
    set(OPTIONS "${OPTIONS} --enable-cuda --enable-nvenc --enable-nvdec --enable-cuvid --enable-ffnvcodec")
else()
    set(OPTIONS "${OPTIONS} --disable-cuda --disable-nvenc --disable-nvdec  --disable-cuvid --disable-ffnvcodec")
endif()

if("opencl" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-opencl")
    set(WITH_OPENCL ON)
else()
    set(OPTIONS "${OPTIONS} --disable-opencl")
    set(WITH_OPENCL OFF)
endif()

if("opengl" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-opengl")
else()
    set(OPTIONS "${OPTIONS} --disable-opengl")
endif()

if("openh264" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libopenh264")
    set(WITH_OPENH264 ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libopenh264")
    set(WITH_OPENH264 OFF)
endif()

if("openjpeg" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libopenjpeg")
    set(WITH_OPENJPEG ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libopenjpeg")
    set(WITH_OPENJPEG OFF)
endif()

if("openmpt" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libopenmpt")
    set(WITH_OPENMPT ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libopenmpt")
    set(WITH_OPENMPT OFF)
endif()

if("openssl" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-openssl")
else()
    set(OPTIONS "${OPTIONS} --disable-openssl")
    if(VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_TARGET_IS_UWP)
        string(APPEND OPTIONS " --enable-schannel")
    elseif(VCPKG_TARGET_IS_OSX)
        string(APPEND OPTIONS " --enable-securetransport")
    elseif(VCPKG_TARGET_IS_IOS)
        string(APPEND OPTIONS " --enable-securetransport")
    endif()
endif()

if("opus" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libopus")
    set(WITH_OPUS ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libopus")
    set(WITH_OPUS OFF)
endif()

if("sdl2" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-sdl2")
else()
    set(OPTIONS "${OPTIONS} --disable-sdl2")
endif()

if("snappy" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libsnappy")
    set(WITH_SNAPPY ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libsnappy")
    set(WITH_SNAPPY OFF)
endif()

if("soxr" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libsoxr")
    set(WITH_SOXR ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libsoxr")
    set(WITH_SOXR OFF)
endif()

if("speex" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libspeex")
    set(WITH_SPEEX ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libspeex")
    set(WITH_SPEEX OFF)
endif()

if("ssh" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libssh")
    set(WITH_SSH ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libssh")
    set(WITH_SSH OFF)
endif()

if("tensorflow" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libtensorflow")
else()
    set(OPTIONS "${OPTIONS} --disable-libtensorflow")
endif()

if("tesseract" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libtesseract")
else()
    set(OPTIONS "${OPTIONS} --disable-libtesseract")
endif()

if("theora" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libtheora")
    set(WITH_THEORA ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libtheora")
    set(WITH_THEORA OFF)
endif()

if("vorbis" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libvorbis")
    set(WITH_VORBIS ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libvorbis")
    set(WITH_VORBIS OFF)
endif()

if("vpx" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libvpx")
    set(WITH_VPX ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libvpx")
    set(WITH_VPX OFF)
endif()

if("webp" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libwebp")
    set(WITH_WEBP ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libwebp")
    set(WITH_WEBP OFF)
endif()

if("x264" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libx264")
    set(WITH_X264 ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libx264")
    set(WITH_X264 OFF)
endif()

if("x265" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libx265")
    set(WITH_X265 ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libx265")
    set(WITH_X265 OFF)
endif()

if("xml2" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libxml2")
    set(WITH_XML2 ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libxml2")
    set(WITH_XML2 OFF)
endif()

if("zlib" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-zlib")
else()
    set(OPTIONS "${OPTIONS} --disable-zlib")
endif()

if ("srt" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libsrt")
    set(WITH_SRT ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libsrt")
    set(WITH_SRT OFF)
endif()

if ("qsv" IN_LIST FEATURES)
    set(OPTIONS "${OPTIONS} --enable-libmfx")
    set(WITH_MFX ON)
else()
    set(OPTIONS "${OPTIONS} --disable-libmfx")
    set(WITH_MFX OFF)
endif()

set(OPTIONS_CROSS "--enable-cross-compile")

# ffmpeg needs --cross-prefix option to use appropriate tools for cross-compiling.
if(VCPKG_DETECTED_CMAKE_C_COMPILER MATCHES "([^\/]*-)gcc$")
    string(APPEND OPTIONS_CROSS " --cross-prefix=${CMAKE_MATCH_1}")
endif()

if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(BUILD_ARCH "x86_64")
else()
    set(BUILD_ARCH ${VCPKG_TARGET_ARCHITECTURE})
endif()

if (VCPKG_TARGET_ARCHITECTURE STREQUAL "arm" OR VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    if(VCPKG_TARGET_IS_WINDOWS)
        vcpkg_find_acquire_program(GASPREPROCESSOR)
        foreach(GAS_PATH ${GASPREPROCESSOR})
            get_filename_component(GAS_ITEM_PATH ${GAS_PATH} DIRECTORY)
            vcpkg_add_to_path("${GAS_ITEM_PATH}")
        endforeach(GAS_PATH)
    endif()
endif()

if(VCPKG_TARGET_IS_UWP)
    set(ENV{LIBPATH} "$ENV{LIBPATH};$ENV{_WKITS10}references\\windows.foundation.foundationcontract\\2.0.0.0\\;$ENV{_WKITS10}references\\windows.foundation.universalapicontract\\3.0.0.0\\")
    string(APPEND OPTIONS " --disable-programs")
    string(APPEND OPTIONS " --extra-cflags=-DWINAPI_FAMILY=WINAPI_FAMILY_APP --extra-cflags=-D_WIN32_WINNT=0x0A00")
    string(APPEND OPTIONS " --extra-ldflags=-APPCONTAINER --extra-ldflags=WindowsApp.lib")
endif()

if (VCPKG_TARGET_IS_IOS)
    set(vcpkg_target_arch "${VCPKG_TARGET_ARCHITECTURE}")
    if (VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(vcpkg_target_arch "x86_64")
    elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
        message(FATAL_ERROR "You can build for arm up to iOS 10 but ffmpeg can only be built for iOS 11.0 and later.
                            Did you mean arm64?")
    elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        message(FATAL_ERROR "You can build for x86 up to iOS 10 but ffmpeg can only be built for iOS 11.0 and later.
                            Did you mean x64")
    endif ()

    set(vcpkg_osx_deployment_target "${VCPKG_OSX_DEPLOYMENT_TARGET}")
    if (NOT VCPKG_OSX_DEPLOYMENT_TARGET)
        set(vcpkg_osx_deployment_target 11.0)
    elseif (VCPKG_OSX_DEPLOYMENT_TARGET LESS 11.0) # nowadays ffmpeg needs to be built for ios 11.0 and later
        message(FATAL_ERROR "ffmpeg can be built only for iOS 11.0 and later but you set VCPKG_OSX_DEPLOYMENT_TARGET to
                            ${VCPKG_OSX_DEPLOYMENT_TARGET}")
    endif ()

    if (VCPKG_OSX_SYSROOT STREQUAL "iphonesimulator")
        set(simulator "-simulator")
    endif ()

    set(OPTIONS "${OPTIONS} --extra-cflags=--target=${vcpkg_target_arch}-apple-ios${vcpkg_osx_deployment_target}${simulator}")
    set(OPTIONS "${OPTIONS} --extra-ldflags=--target=${vcpkg_target_arch}-apple-ios${vcpkg_osx_deployment_target}${simulator}")

    set(vcpkg_osx_sysroot "${VCPKG_OSX_SYSROOT}")
    # only on x64 for some reason you need to specify the sdk path, otherwise it will try to build with the MacOS sdk
    # (on apple silicon it's not required but shouldn't cause any problems)
    if ((VCPKG_OSX_SYSROOT MATCHES "^(iphoneos|iphonesimulator)$") OR (NOT VCPKG_OSX_SYSROOT) OR (VCPKG_OSX_SYSROOT STREQUAL "")) # if it's not a path
        if (VCPKG_OSX_SYSROOT MATCHES "^(iphoneos|iphonesimulator)$")
            set(requested_sysroot "${VCPKG_OSX_SYSROOT}")
        elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64") # if the sysroot is not specified we have to guess
            set(requested_sysroot "iphoneos")
        elseif (VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(requested_sysroot "iphonesimulator")
        else ()
            message(FATAL_ERROR "Unsupported build arch: ${VCPKG_TARGET_ARCHITECTURE}")
        endif ()
        message(STATUS "Retrieving default SDK for ${requested_sysroot}")
        execute_process(
                COMMAND /usr/bin/xcrun --sdk ${requested_sysroot} --show-sdk-path
                OUTPUT_VARIABLE sdk_path
                ERROR_VARIABLE xcrun_error
                OUTPUT_STRIP_TRAILING_WHITESPACE
                ERROR_STRIP_TRAILING_WHITESPACE
        )
        if (sdk_path)
            message(STATUS "Found!")
            set(vcpkg_osx_sysroot "${sdk_path}")
        else ()
            message(FATAL_ERROR "Can't determine ${CMAKE_OSX_SYSROOT} SDK path. Error: ${xcrun_error}")
        endif ()
    endif ()
    set(OPTIONS "${OPTIONS} --extra-cflags=-isysroot\"${vcpkg_osx_sysroot}\"")
    set(OPTIONS "${OPTIONS} --extra-ldflags=-isysroot\"${vcpkg_osx_sysroot}\"")
endif ()

set(OPTIONS_DEBUG "--disable-optimizations")
set(OPTIONS_RELEASE "--enable-optimizations")

set(OPTIONS "${OPTIONS} ${OPTIONS_CROSS}")

if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    set(OPTIONS "${OPTIONS} --disable-static --enable-shared")
endif()

if(VCPKG_TARGET_IS_MINGW)
    set(OPTIONS "${OPTIONS} --extra_cflags=-D_WIN32_WINNT=0x0601")
elseif(VCPKG_TARGET_IS_WINDOWS)
    set(OPTIONS "${OPTIONS} --extra-cflags=-DHAVE_UNISTD_H=0")
endif()

set(maybe_needed_libraries -lm)
separate_arguments(standard_libraries NATIVE_COMMAND "${VCPKG_DETECTED_CMAKE_C_STANDARD_LIBRARIES}")
foreach(item IN LISTS standard_libraries)
    if(item IN_LIST maybe_needed_libraries)
        set(OPTIONS "${OPTIONS} \"--extra-libs=${item}\"")
    endif()
endforeach()

vcpkg_find_acquire_program(PKGCONFIG)
set(OPTIONS "${OPTIONS} --pkg-config=\"${PKGCONFIG}\"")
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    set(OPTIONS "${OPTIONS} --pkg-config-flags=--static")
endif()

message(STATUS "Building Options: ${OPTIONS}")

# Release build
if (NOT VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
    if (VCPKG_DETECTED_MSVC)
        set(OPTIONS_RELEASE "${OPTIONS_RELEASE} --extra-ldflags=-libpath:\"${CURRENT_INSTALLED_DIR}/lib\"")
    else()
        set(OPTIONS_RELEASE "${OPTIONS_RELEASE} --extra-ldflags=-L\"${CURRENT_INSTALLED_DIR}/lib\"")
    endif()
    message(STATUS "Building Release Options: ${OPTIONS_RELEASE}")
    message(STATUS "Building ${PORT} for Release")
    file(MAKE_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
    # We use response files here as the only known way to handle spaces in paths
    set(crsp "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/cflags.rsp")
    string(REGEX REPLACE "-arch [A-Za-z0-9_]+" "" VCPKG_COMBINED_C_FLAGS_RELEASE_SANITIZED "${VCPKG_COMBINED_C_FLAGS_RELEASE}")
    file(WRITE "${crsp}" "${VCPKG_COMBINED_C_FLAGS_RELEASE_SANITIZED}")
    set(ldrsp "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/ldflags.rsp")
    string(REGEX REPLACE "-arch [A-Za-z0-9_]+" "" VCPKG_COMBINED_SHARED_LINKER_FLAGS_RELEASE_SANITIZED "${VCPKG_COMBINED_SHARED_LINKER_FLAGS_RELEASE}")
    file(WRITE "${ldrsp}" "${VCPKG_COMBINED_SHARED_LINKER_FLAGS_RELEASE_SANITIZED}")
    set(ENV{CFLAGS} "@${crsp}")
    # All tools except the msvc arm{,64} assembler accept @... as response file syntax.
    # For that assembler, there is no known way to pass in flags. We must hope that not passing flags will work acceptably.
    if(NOT VCPKG_DETECTED_MSVC OR NOT VCPKG_TARGET_ARCHITECTURE MATCHES "^arm")
        set(ENV{ASFLAGS} "@${crsp}")
    endif()
    set(ENV{LDFLAGS} "@${ldrsp}")
    set(ENV{ARFLAGS} "${VCPKG_COMBINED_STATIC_LINKER_FLAGS_RELEASE}")

    set(BUILD_DIR         "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
    set(CONFIGURE_OPTIONS "${OPTIONS} ${OPTIONS_RELEASE}")
    set(INST_PREFIX       "${CURRENT_PACKAGES_DIR}")

    configure_file("${CMAKE_CURRENT_LIST_DIR}/build.sh.in" "${BUILD_DIR}/build.sh" @ONLY)

    z_vcpkg_setup_pkgconfig_path(CONFIG RELEASE)

    vcpkg_execute_required_process(
        COMMAND "${SHELL}" ./build.sh
        WORKING_DIRECTORY "${BUILD_DIR}"
        LOGNAME "build-${TARGET_TRIPLET}-rel"
        SAVE_LOG_FILES ffbuild/config.log
    )

    z_vcpkg_restore_pkgconfig_path()
endif()

# Debug build
if (NOT VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
    if (VCPKG_DETECTED_MSVC)
        set(OPTIONS_DEBUG "${OPTIONS_DEBUG} --extra-ldflags=-libpath:\"${CURRENT_INSTALLED_DIR}/debug/lib\"")
    else()
        set(OPTIONS_DEBUG "${OPTIONS_DEBUG} --extra-ldflags=-L\"${CURRENT_INSTALLED_DIR}/debug/lib\"")
    endif()
    message(STATUS "Building Debug Options: ${OPTIONS_DEBUG}")
    message(STATUS "Building ${PORT} for Debug")
    file(MAKE_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg")
    set(crsp "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg/cflags.rsp")
    string(REGEX REPLACE "-arch [A-Za-z0-9_]+" "" VCPKG_COMBINED_C_FLAGS_DEBUG_SANITIZED "${VCPKG_COMBINED_C_FLAGS_DEBUG}")
    file(WRITE "${crsp}" "${VCPKG_COMBINED_C_FLAGS_DEBUG_SANITIZED}")
    set(ldrsp "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg/ldflags.rsp")
    string(REGEX REPLACE "-arch [A-Za-z0-9_]+" "" VCPKG_COMBINED_SHARED_LINKER_FLAGS_DEBUG_SANITIZED "${VCPKG_COMBINED_SHARED_LINKER_FLAGS_DEBUG}")
    file(WRITE "${ldrsp}" "${VCPKG_COMBINED_SHARED_LINKER_FLAGS_DEBUG_SANITIZED}")
    set(ENV{CFLAGS} "@${crsp}")
    if(NOT VCPKG_DETECTED_MSVC OR NOT VCPKG_TARGET_ARCHITECTURE MATCHES "^arm")
        set(ENV{ASFLAGS} "@${crsp}")
    endif()
    set(ENV{LDFLAGS} "@${ldrsp}")
    set(ENV{ARFLAGS} "${VCPKG_COMBINED_STATIC_LINKER_FLAGS_DEBUG}")

    set(BUILD_DIR         "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg")
    set(CONFIGURE_OPTIONS "${OPTIONS} ${OPTIONS_DEBUG}")
    set(INST_PREFIX       "${CURRENT_PACKAGES_DIR}/debug")

    configure_file("${CMAKE_CURRENT_LIST_DIR}/build.sh.in" "${BUILD_DIR}/build.sh" @ONLY)

    z_vcpkg_setup_pkgconfig_path(CONFIG DEBUG)

    vcpkg_execute_required_process(
        COMMAND "${SHELL}" ./build.sh
        WORKING_DIRECTORY "${BUILD_DIR}"
        LOGNAME "build-${TARGET_TRIPLET}-dbg"
        SAVE_LOG_FILES ffbuild/config.log
    )

    z_vcpkg_restore_pkgconfig_path()
endif()

if(VCPKG_TARGET_IS_WINDOWS)
    file(GLOB DEF_FILES "${CURRENT_PACKAGES_DIR}/lib/*.def" "${CURRENT_PACKAGES_DIR}/debug/lib/*.def")

    if(NOT VCPKG_TARGET_IS_MINGW)
        if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
            set(LIB_MACHINE_ARG /machine:ARM)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
            set(LIB_MACHINE_ARG /machine:ARM64)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
            set(LIB_MACHINE_ARG /machine:x86)
        elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
            set(LIB_MACHINE_ARG /machine:x64)
        else()
            message(FATAL_ERROR "Unsupported target architecture")
        endif()

        foreach(DEF_FILE ${DEF_FILES})
            get_filename_component(DEF_FILE_DIR "${DEF_FILE}" DIRECTORY)
            get_filename_component(DEF_FILE_NAME "${DEF_FILE}" NAME)
            string(REGEX REPLACE "-[0-9]*\\.def" "${VCPKG_TARGET_STATIC_LIBRARY_SUFFIX}" OUT_FILE_NAME "${DEF_FILE_NAME}")
            file(TO_NATIVE_PATH "${DEF_FILE}" DEF_FILE_NATIVE)
            file(TO_NATIVE_PATH "${DEF_FILE_DIR}/${OUT_FILE_NAME}" OUT_FILE_NATIVE)
            message(STATUS "Generating ${OUT_FILE_NATIVE}")
            vcpkg_execute_required_process(
                COMMAND lib.exe "/def:${DEF_FILE_NATIVE}" "/out:${OUT_FILE_NATIVE}" ${LIB_MACHINE_ARG}
                WORKING_DIRECTORY "${CURRENT_PACKAGES_DIR}"
                LOGNAME "libconvert-${TARGET_TRIPLET}"
            )
        endforeach()
    endif()

    file(GLOB EXP_FILES "${CURRENT_PACKAGES_DIR}/lib/*.exp" "${CURRENT_PACKAGES_DIR}/debug/lib/*.exp")
    file(GLOB LIB_FILES "${CURRENT_PACKAGES_DIR}/bin/*${VCPKG_TARGET_STATIC_LIBRARY_SUFFIX}" "${CURRENT_PACKAGES_DIR}/debug/bin/*${VCPKG_TARGET_STATIC_LIBRARY_SUFFIX}")
    if(VCPKG_TARGET_IS_MINGW)
        file(GLOB LIB_FILES_2 "${CURRENT_PACKAGES_DIR}/bin/*.lib" "${CURRENT_PACKAGES_DIR}/debug/bin/*.lib")
    endif()
    set(files_to_remove ${EXP_FILES} ${LIB_FILES} ${LIB_FILES_2} ${DEF_FILES})
    if(files_to_remove)
        file(REMOVE ${files_to_remove})
    endif()
endif()

if("ffmpeg" IN_LIST FEATURES)
    vcpkg_copy_tools(TOOL_NAMES ffmpeg AUTO_CLEAN)
endif()
if("ffprobe" IN_LIST FEATURES)
    vcpkg_copy_tools(TOOL_NAMES ffprobe AUTO_CLEAN)
endif()
if("ffplay" IN_LIST FEATURES)
    vcpkg_copy_tools(TOOL_NAMES ffplay AUTO_CLEAN)
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")

if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/bin" "${CURRENT_PACKAGES_DIR}/debug/bin")
endif()

vcpkg_copy_pdbs()

if(VCPKG_TARGET_IS_WINDOWS)
    file(GLOB pc_files "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/*.pc" "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/*.pc")
    foreach(file IN LISTS pc_files)
        # ffmpeg exports -libpath:foo and bar.lib for transitive deps.
        # But CMake's pkg_check_modules cannot handle this properly.
        # pc files generally use non-msvc syntax with -Lfoo -lbar.
        file(READ "${file}" content)
        foreach(entry IN ITEMS Libs Libs.private)
            if(content MATCHES "${entry}: ([^\n]*)")
                set(old_value "${CMAKE_MATCH_1}")
                string(REGEX REPLACE "-libpath:" "-L" new_value "${old_value}")
                string(REGEX REPLACE " ([^ /]+)[.]lib" " -l\\1" new_value "${new_value}")
                string(REPLACE "${entry}: ${old_value}" "${entry}: ${new_value}" content "${content}")
            endif()
        endforeach()
        file(WRITE "${file}" "${content}")
    endforeach()
endif()
vcpkg_fixup_pkgconfig()

# Handle dependencies

x_vcpkg_pkgconfig_get_modules(PREFIX FFMPEG_PKGCONFIG MODULES ${FFMPEG_PKGCONFIG_MODULES} LIBS)

function(append_dependencies_from_libs out)
    cmake_parse_arguments(PARSE_ARGV 1 "arg" "" "LIBS" "")
    string(REGEX REPLACE "[ ]+" ";" contents "${arg_LIBS}")
    list(FILTER contents EXCLUDE REGEX "^-F.+")
    list(FILTER contents EXCLUDE REGEX "^-framework$")
    list(FILTER contents EXCLUDE REGEX "^-L.+")
    list(FILTER contents EXCLUDE REGEX "^-libpath:.+")
    list(TRANSFORM contents REPLACE "^-Wl,-framework," "-l")
    list(FILTER contents EXCLUDE REGEX "^-Wl,.+")
    list(TRANSFORM contents REPLACE "^-l" "")
    list(FILTER contents EXCLUDE REGEX "^avutil$")
    list(FILTER contents EXCLUDE REGEX "^avcodec$")
    list(FILTER contents EXCLUDE REGEX "^avdevice$")
    list(FILTER contents EXCLUDE REGEX "^avfilter$")
    list(FILTER contents EXCLUDE REGEX "^avformat$")
    list(FILTER contents EXCLUDE REGEX "^postproc$")
    list(FILTER contents EXCLUDE REGEX "^swresample$")
    list(FILTER contents EXCLUDE REGEX "^swscale$")
    if(VCPKG_TARGET_IS_WINDOWS)
        list(TRANSFORM contents TOLOWER)
    endif()
    if(contents)
        list(APPEND "${out}" "${contents}")
        set("${out}" "${${out}}" PARENT_SCOPE)
    endif()
endfunction()

append_dependencies_from_libs(FFMPEG_DEPENDENCIES_RELEASE LIBS "${FFMPEG_PKGCONFIG_LIBS_RELEASE}")
append_dependencies_from_libs(FFMPEG_DEPENDENCIES_DEBUG   LIBS "${FFMPEG_PKGCONFIG_LIBS_DEBUG}")

# must remove duplicates from the front to respect link order so reverse first
list(REVERSE FFMPEG_DEPENDENCIES_RELEASE)
list(REVERSE FFMPEG_DEPENDENCIES_DEBUG)
list(REMOVE_DUPLICATES FFMPEG_DEPENDENCIES_RELEASE)
list(REMOVE_DUPLICATES FFMPEG_DEPENDENCIES_DEBUG)
list(REVERSE FFMPEG_DEPENDENCIES_RELEASE)
list(REVERSE FFMPEG_DEPENDENCIES_DEBUG)

message(STATUS "Dependencies (release): ${FFMPEG_DEPENDENCIES_RELEASE}")
message(STATUS "Dependencies (debug):   ${FFMPEG_DEPENDENCIES_DEBUG}")

# Handle version strings

function(extract_regex_from_file out)
    cmake_parse_arguments(PARSE_ARGV 1 "arg" "MAJOR" "FILE_WITHOUT_EXTENSION;REGEX" "")
    file(READ "${arg_FILE_WITHOUT_EXTENSION}.h" contents)
    if (contents MATCHES "${arg_REGEX}")
        if(NOT CMAKE_MATCH_COUNT EQUAL 1)
            message(FATAL_ERROR "Could not identify match group in regular expression \"${arg_REGEX}\"")
        endif()
    else()
        if (arg_MAJOR)
            file(READ "${arg_FILE_WITHOUT_EXTENSION}_major.h" contents)
            if (contents MATCHES "${arg_REGEX}")
                if(NOT CMAKE_MATCH_COUNT EQUAL 1)
                    message(FATAL_ERROR "Could not identify match group in regular expression \"${arg_REGEX}\"")
                endif()
            else()
                message(WARNING "Could not find line matching \"${arg_REGEX}\" in file \"${arg_FILE_WITHOUT_EXTENSION}_major.h\"")
            endif()
        else()
            message(WARNING "Could not find line matching \"${arg_REGEX}\" in file \"${arg_FILE_WITHOUT_EXTENSION}.h\"")
        endif()
    endif()
    set("${out}" "${CMAKE_MATCH_1}" PARENT_SCOPE)
endfunction()

function(extract_version_from_component out)
    cmake_parse_arguments(PARSE_ARGV 1 "arg" "" "COMPONENT" "")
    string(TOLOWER "${arg_COMPONENT}" component_lower)
    string(TOUPPER "${arg_COMPONENT}" component_upper)
    extract_regex_from_file(major_version
        FILE_WITHOUT_EXTENSION "${SOURCE_PATH}/${component_lower}/version"
        MAJOR
        REGEX "#define ${component_upper}_VERSION_MAJOR[ ]+([0-9]+)"
    )
    extract_regex_from_file(minor_version
        FILE_WITHOUT_EXTENSION "${SOURCE_PATH}/${component_lower}/version"
        REGEX "#define ${component_upper}_VERSION_MINOR[ ]+([0-9]+)"
    )
    extract_regex_from_file(micro_version
        FILE_WITHOUT_EXTENSION "${SOURCE_PATH}/${component_lower}/version"
        REGEX "#define ${component_upper}_VERSION_MICRO[ ]+([0-9]+)"
    )
    set("${out}" "${major_version}.${minor_version}.${micro_version}" PARENT_SCOPE)
endfunction()

extract_regex_from_file(FFMPEG_VERSION
    FILE_WITHOUT_EXTENSION "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/libavutil/ffversion"
    REGEX "#define FFMPEG_VERSION[ ]+\"(.+)\""
)

extract_version_from_component(LIBAVUTIL_VERSION
    COMPONENT libavutil)
extract_version_from_component(LIBAVCODEC_VERSION
    COMPONENT libavcodec)
extract_version_from_component(LIBAVDEVICE_VERSION
    COMPONENT libavdevice)
extract_version_from_component(LIBAVFILTER_VERSION
    COMPONENT libavfilter)
extract_version_from_component(LIBAVFORMAT_VERSION
    COMPONENT libavformat)
extract_version_from_component(LIBSWRESAMPLE_VERSION
    COMPONENT libswresample)
extract_version_from_component(LIBSWSCALE_VERSION
    COMPONENT libswscale)

# Handle copyright
file(STRINGS "${CURRENT_BUILDTREES_DIR}/build-${TARGET_TRIPLET}-rel-out.log" LICENSE_STRING REGEX "License: .*" LIMIT_COUNT 1)
if(LICENSE_STRING STREQUAL "License: LGPL version 2.1 or later")
    set(LICENSE_FILE "COPYING.LGPLv2.1")
elseif(LICENSE_STRING STREQUAL "License: LGPL version 3 or later")
    set(LICENSE_FILE "COPYING.LGPLv3")
elseif(LICENSE_STRING STREQUAL "License: GPL version 2 or later")
    set(LICENSE_FILE "COPYING.GPLv2")
elseif(LICENSE_STRING STREQUAL "License: GPL version 3 or later")
    set(LICENSE_FILE "COPYING.GPLv3")
elseif(LICENSE_STRING STREQUAL "License: nonfree and unredistributable")
    set(LICENSE_FILE "COPYING.NONFREE")
    file(WRITE "${SOURCE_PATH}/${LICENSE_FILE}" "${LICENSE_STRING}")
else()
    message(FATAL_ERROR "Failed to identify license (${LICENSE_STRING})")
endif()

configure_file("${CMAKE_CURRENT_LIST_DIR}/FindFFMPEG.cmake.in" "${CURRENT_PACKAGES_DIR}/share/${PORT}/FindFFMPEG.cmake" @ONLY)
configure_file("${CMAKE_CURRENT_LIST_DIR}/vcpkg-cmake-wrapper.cmake" "${CURRENT_PACKAGES_DIR}/share/${PORT}/vcpkg-cmake-wrapper.cmake" @ONLY)

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static" AND NOT VCPKG_TARGET_IS_WINDOWS AND NOT VCPKG_TARGET_IS_OSX AND NOT VCPKG_TARGET_IS_IOS)
    file(APPEND "${CURRENT_PACKAGES_DIR}/share/${PORT}/usage" "
To use the static libraries to build your own shared library,
you may need to add the following link option for your library:

  -Wl,-Bsymbolic
")
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/${LICENSE_FILE}")
