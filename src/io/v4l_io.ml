external caps : Unix.file_descr -> string * int * int * int * int * int * int = "caml_v4l_caps"
external init : Unix.file_descr -> unit = "caml_v4l_init"
external get_dims : Unix.file_descr -> int * int = "caml_v4l_get_dims"
external capture : Unix.file_descr -> int -> int -> string = "caml_v4l_capture"

class input dev =
object (self)
  inherit Source.active_source

  val mutable fd = None

  method stype = Source.Infallible
  method remaining = -1
  method abort_track = ()
  method output = if AFrame.is_partial memo then self#get_frame memo

  val mutable width = 0
  val mutable height = 0

  method output_get_ready =
    fd <- Some (Unix.openfile dev [Unix.O_RDWR] 0);
    let fd = Utils.get_some fd in
    let name, _, _, maxw, maxh, _, _ = caps fd in
      init fd;
      let w, h = get_dims fd in
        width <- w;
        height <- h

  method output_reset = ()

  method get_frame frame =
    assert (0 = AFrame.position frame);
    let fd = Utils.get_some fd in
    let buf = VFrame.get_rgb frame in
    let img =
      (*
      let buflen = width * height * 3 in
      let buf = String.make buflen '\000' in
        ignore (Unix.read fd buf 0 buflen);
        buf
       *)
      capture fd width height
    in
    let img = RGB.of_linear_rgb img width in
      for c = 0 to Array.length buf - 1 do
        for i = 0 to VFrame.size frame - 1 do
          RGB.proportional_scale buf.(c).(i) img
        done;
      done;
      AFrame.add_break frame (AFrame.size frame)
end

let () =
  Lang.add_operator "input.v4l"
    [
      "device", Lang.string_t, Some (Lang.string "/dev/video0"), Some "V4L device to use.";
    ]
    ~category:Lang.Input
    ~descr:"Stream from a V4L (= video 4 linux) input device, such as a webcam."
    (fun p ->
       let e f v = f (List.assoc v p) in
       let device = e Lang.to_string "device" in
         ((new input device):>Source.source)
    )
