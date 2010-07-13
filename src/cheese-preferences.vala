using Gtk;

internal class Cheese.PreferencesDialog : GLib.Object
{
  private Cheese.Camera camera;
  private Cheese.GConf  conf;

  private Gtk.Dialog dialog;

  private Gtk.ComboBox resolution_combo;
  private Gtk.ComboBox source_combo;

  private Gtk.Adjustment brightness_adjustment;
  private Gtk.Adjustment contrast_adjustment;
  private Gtk.Adjustment hue_adjustment;
  private Gtk.Adjustment saturation_adjustment;

  private Gtk.SpinButton burst_repeat_spin;
  private Gtk.SpinButton burst_delay_spin;

  public PreferencesDialog (Cheese.Camera camera, Cheese.GConf conf)
  {
    this.camera = camera;
    this.conf   = conf;

    Gtk.Builder builder = new Gtk.Builder ();
    builder.add_from_file (GLib.Path.build_filename (Config.PACKAGE_DATADIR, "cheese-prefs.ui"));
    builder.connect_signals (this);

    this.dialog = (Gtk.Dialog)builder.get_object ("cheese_prefs_dialog");

    this.brightness_adjustment = (Gtk.Adjustment)builder.get_object ("brightness_adjustment");
    this.contrast_adjustment   = (Gtk.Adjustment)builder.get_object ("contrast_adjustment");
    this.hue_adjustment        = (Gtk.Adjustment)builder.get_object ("hue_adjustment");
    this.saturation_adjustment = (Gtk.Adjustment)builder.get_object ("saturation_adjustment");

    this.resolution_combo = (Gtk.ComboBox)builder.get_object ("resolution_combo_box");
    this.source_combo     = (Gtk.ComboBox)builder.get_object ("camera_combo_box");

    this.burst_repeat_spin = (Gtk.SpinButton)builder.get_object ("burst_repeat");
    this.burst_delay_spin  = (Gtk.SpinButton)builder.get_object ("burst_delay");

    initialize_camera_devices ();
    initialize_values_from_conf ();
  }

  private void initialize_camera_devices ()
  {
    Cheese.CameraDevice   dev;
    TreeIter              active_dev;
    unowned GLib.PtrArray devices = camera.get_camera_devices ();
    ListStore             model   = new ListStore (2, typeof (string), typeof (Cheese.CameraDevice));

    source_combo.model = model;

    for (int i = 0; i < devices.len; i++)
    {
      TreeIter iter;
      dev = (Cheese.CameraDevice)devices.index (i);
      model.append (out iter);
      model.set (iter,
                 0, dev.get_name () + " (" + dev.get_device_file () + " )",
                 1, dev);
      if (camera.get_selected_device ().get_device_file () == dev.get_device_file ())
      {
        source_combo.set_active_iter (iter);
      }
    }

    CellRendererText cell = new CellRendererText ();
    source_combo.pack_start (cell, false);
    source_combo.set_attributes (cell, "text", 0);

    setup_resolutions_for_device (camera.get_selected_device ());
  }

  private void setup_resolutions_for_device (Cheese.CameraDevice device)
  {
    unowned List<VideoFormat>  formats = device.get_format_list ();
    ListStore                  model   = new ListStore (2, typeof (string), typeof (Cheese.VideoFormat));
    unowned Cheese.VideoFormat format;

    resolution_combo.model = model;

    for (int i = 0; i < formats.length (); i++)
    {
      TreeIter iter;
      format = formats<VideoFormat>.nth (i).data;
      model.append (out iter);
      model.set (iter,
                 0, format.width.to_string () + " x " + format.height.to_string (),
                 1, format);
      if (camera.get_current_video_format ().width == format.width &&
          camera.get_current_video_format ().height == format.height)
      {
        resolution_combo.set_active_iter (iter);
      }
    }
    CellRendererText cell = new CellRendererText ();
    resolution_combo.pack_start (cell, false);
    resolution_combo.set_attributes (cell, "text", 0);
  }

  private void initialize_values_from_conf ()
  {
    brightness_adjustment.value = conf.gconf_prop_brightness;
    contrast_adjustment.value   = conf.gconf_prop_contrast;
    hue_adjustment.value        = conf.gconf_prop_hue;
    saturation_adjustment.value = conf.gconf_prop_saturation;

    burst_repeat_spin.value = conf.gconf_prop_burst_repeat;
    burst_delay_spin.value  = conf.gconf_prop_burst_delay / 1000;
  }

  [CCode (instance_pos = -1)]
  internal void on_source_change (Gtk.ComboBox combo)
  {
    TreeIter iter;

    Cheese.CameraDevice dev;

    combo.get_active_iter (out iter);
    combo.model.get (iter, 1, out dev);
    camera.set_device_by_dev_file (dev.get_device_file ());
    camera.switch_camera_device ();
    setup_resolutions_for_device (camera.get_selected_device ());
    conf.gconf_prop_camera = dev.get_device_file ();
  }

  [CCode (instance_pos = -1)]
  internal void on_resolution_change (Gtk.ComboBox combo)
  {
    TreeIter iter;

    unowned Cheese.VideoFormat format;

    combo.get_active_iter (out iter);
    combo.model.get (iter, 1, out format);
    camera.set_video_format (format);

    conf.gconf_prop_x_resolution = format.width;
    conf.gconf_prop_y_resolution = format.height;
  }

  [CCode (instance_pos = -1)]
  internal void on_dialog_close (Gtk.Button button)
  {
    this.dialog.hide_all ();
  }

  [CCode (instance_pos = -1)]
  internal void on_burst_repeat_change (Gtk.SpinButton spinbutton)
  {
    conf.gconf_prop_burst_repeat = (int) spinbutton.value;
  }

  [CCode (instance_pos = -1)]
  internal void on_burst_delay_change (Gtk.SpinButton spinbutton)
  {
    conf.gconf_prop_burst_delay = (int) spinbutton.value * 1000;
  }

  [CCode (instance_pos = -1)]
  internal void on_brightness_change (Gtk.Adjustment adjustment)
  {
    this.camera.set_balance_property ("brightness", adjustment.value);
    conf.gconf_prop_brightness = adjustment.value;
  }

  [CCode (instance_pos = -1)]
  internal void on_contrast_change (Gtk.Adjustment adjustment)
  {
    this.camera.set_balance_property ("contrast", adjustment.value);
    conf.gconf_prop_contrast = adjustment.value;
  }

  [CCode (instance_pos = -1)]
  internal void on_hue_change (Gtk.Adjustment adjustment)
  {
    this.camera.set_balance_property ("hue", adjustment.value);
    conf.gconf_prop_hue = adjustment.value;
  }

  [CCode (instance_pos = -1)]
  internal void on_saturation_change (Gtk.Adjustment adjustment)
  {
    this.camera.set_balance_property ("saturation", adjustment.value);
    conf.gconf_prop_saturation = adjustment.value;
  }

  public void show ()
  {
    this.dialog.show_all ();
  }
}
