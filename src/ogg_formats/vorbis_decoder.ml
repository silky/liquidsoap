(*****************************************************************************

  Liquidsoap, a programmable audio stream generator.
  Copyright 2003-2008 Savonet team

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details, fully stated in the COPYING
  file at the root of the liquidsoap distribution.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

 *****************************************************************************)

module Generator = Float_pcm.Generator

let check = Vorbis.Decoder.check_packet

let buflen = 1024

let decoder os =
  let chan _ = Array.make buflen 0. in
  (* TODO: multiple channels.. *)
  let buf = Array.init 2 chan in
  let decoder = ref None in
  let meta    = ref None in
  let packet1 = ref None in
  let packet2 = ref None in
  let packet3 = ref None in
  let fill feed = 
    (* Decoder is created upon first decoding..*)
    let decoder,sample_freq = 
      match !decoder with
        | None -> 
           let packet1 =
             match !packet1 with
               | None ->
                  let p = Ogg.Stream.get_packet os in
                  packet1 := Some p; p
               | Some p -> p
           in
           let packet2 = 
             match !packet2 with
               | None -> 
                  let p = Ogg.Stream.get_packet os in
                  packet2 := Some p; p
               | Some p -> p
           in
           let packet3 = 
             match !packet3 with
               | None ->
                   let p = Ogg.Stream.get_packet os in
                   packet3 := Some p; p
               | Some p -> p
           in
           let d = Vorbis.Decoder.init packet1 packet2 packet3 in
           let info = Vorbis.Decoder.info d in
           meta := Some (Vorbis.Decoder.comments d);
           let samplerate = info.Vorbis.audio_samplerate in
           decoder := Some (d,samplerate);
           d,samplerate
        | Some d -> d
    in
    try
      let ret = Vorbis.Decoder.decode_pcm decoder os buf 0 buflen in
      let m = ! meta in
      meta := None;
      feed ((Array.map (fun x -> Array.sub x 0 ret) buf,sample_freq),m)
    with
      (* Apparently, we should hide this one.. *)
      | Vorbis.False -> raise Ogg.Not_enough_data
  in
  Ogg_demuxer.Audio fill

let () = Ogg_demuxer.ogg_decoders#register "vorbis" (check,decoder)

