# WORDLOS - Wordle Clone for DOS

Just another clone of Wordle for DOS using x86 16bit Assembly.

![WORDLOS for DOS](/screenshot/wordlos1.gif)

## Download

Binary version of this game can be downloaded at the [Releases](https://github.com/CrociDB/wordlos/releases) section.

## Play Online

I did an overengineered web-version of this game and published it on _itch.io_ and can be played at: https://crocidb.itch.io/wordlos

This runs on a wasm version of DosBox and send the output framebuffer to a WebGL context that renders it with a post-processing effect to look more like a CRT screen.

## Building

*WORDLOS* is built using *NASM*. So once you have that installed, all you need to do is:

`$ make`

In case there are no make tool available, you can directly compile it with:

`$ nasm -f bin -o wordlos.com wordlos.asm`

In both cases, a `wordlos.com` file will be generated and it can be run on DOS, DosBox or FreeDOS.

## License

This project is licensed under the MIT License.

## Contributors

 - [Paweł Łukasik](https://github.com/pawlos)
