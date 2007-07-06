/*
 * Copyright (C) 2007 Copyright (C) 2007 daniel g. siegel <dgsiegel@gmail.com>
 *
 * Licensed under the GNU General Public License Version 2
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <pwd.h>
#include <dirent.h>
#include <libintl.h>
#include <unistd.h>

#include <glib.h>
#include <gdk/gdk.h>
#include <gdk/gdkx.h>
#include <libgnomevfs/gnome-vfs.h>

#include <gst/interfaces/xoverlay.h>
#include <gdk-pixbuf/gdk-pixbuf.h>

#include "cheese_config.h"
#include "cheese.h"
#include "pipeline-photo.h"
#include "fileutil.h"
#include "thumbnails.h"
#include "window.h"
#include "effects-widget.h"

#define _(str) gettext(str)

struct _cheese_window cheese_window;
struct _thumbnails thumbnails;

GnomeVFSMonitorHandle *monitor_handle = NULL;
Pipeline *PipelinePhoto;

void
on_cheese_window_close_cb(GtkWidget *widget, gpointer data)
{
  pipeline_set_stop(PipelinePhoto);
  g_object_unref(G_OBJECT(PipelinePhoto));
  gnome_vfs_monitor_cancel(monitor_handle);
  gtk_main_quit();
}

void
create_photo(unsigned char *data)
{
  int i;
  gchar *filename = NULL;
  GnomeVFSURI *uri;
  GdkPixbuf *pixbuf;

  i = 1;
  filename = get_cheese_filename(i);

  uri = gnome_vfs_uri_new(filename);

  while (gnome_vfs_uri_exists(uri)) {
    i++;
    filename = get_cheese_filename(i);
    g_free(uri);
    uri = gnome_vfs_uri_new(filename);
  }
  g_free(uri);

  pixbuf = gdk_pixbuf_new_from_data (data, 
      GDK_COLORSPACE_RGB, 
      FALSE, 
      8, 
      PHOTO_WIDTH, 
      PHOTO_HEIGHT, 
      PHOTO_WIDTH * 3, 
      NULL, NULL);
  gdk_pixbuf_save(pixbuf, filename, "jpeg", NULL, NULL);
  //gdk_pixbuf_save(pixbuf, filename, "png", NULL, NULL);
  g_object_unref(G_OBJECT(pixbuf));

  g_print("Photo saved: %s\n", filename);
}

gboolean
expose_cb(GtkWidget *widget, GdkEventExpose *event, gpointer data)
{
  GstElement *tmp = gst_bin_get_by_interface(GST_BIN(pipeline_get_pipeline(PipelinePhoto)), GST_TYPE_X_OVERLAY);
  gst_x_overlay_set_xwindow_id(GST_X_OVERLAY(tmp),
      GDK_WINDOW_XWINDOW(widget->window));
  // this is for using x(v)imagesink natively:
  //gst_x_overlay_set_xwindow_id(GST_X_OVERLAY(data),
  //    GDK_WINDOW_XWINDOW(widget->window));
  return FALSE;
}

gboolean
set_screen_x_window_id()
{
  gtk_notebook_set_current_page(GTK_NOTEBOOK(cheese_window.widgets.notebook), 0);
  GstElement *tmp = gst_bin_get_by_interface(GST_BIN(pipeline_get_pipeline(PipelinePhoto)), GST_TYPE_X_OVERLAY);
  gst_x_overlay_set_xwindow_id(GST_X_OVERLAY(tmp),
      GDK_WINDOW_XWINDOW(cheese_window.widgets.screen->window));
  return FALSE;
}

int
main(int argc, char **argv)
{
  gchar *path = NULL;
  GnomeVFSURI *uri;

  gtk_init(&argc, &argv);
  glade_init();
  gst_init(&argc, &argv);
  gnome_vfs_init();
	g_type_init();

  bindtextdomain(CHEESE_PACKAGE_NAME, CHEESE_LOCALE_DIR);
  textdomain(CHEESE_PACKAGE_NAME);

  gtk_window_set_default_icon_name("cheese");
  create_window();

  effects_widget_init();
  gtk_notebook_append_page(GTK_NOTEBOOK(cheese_window.widgets.notebook), cheese_window.widgets.effects_widget, gtk_label_new(NULL));

  PipelinePhoto = PIPELINE(pipeline_new());
  pipeline_create(PipelinePhoto);
  pipeline_set_play(PipelinePhoto);

  path = get_cheese_path();
  uri = gnome_vfs_uri_new(path);

  if (!gnome_vfs_uri_exists(uri)) {
    gnome_vfs_make_directory_for_uri(uri, 0775);
    g_print("creating new directory: %s\n", path);
  }

  create_thumbnails_store();
  gtk_icon_view_set_model(GTK_ICON_VIEW(thumbnails.iconview), GTK_TREE_MODEL(thumbnails.store));
  fill_thumbs();

  gnome_vfs_monitor_add(&monitor_handle, get_cheese_path(),
      GNOME_VFS_MONITOR_DIRECTORY,
      (GnomeVFSMonitorCallback)photos_monitor_cb, NULL);

  g_signal_connect(G_OBJECT(cheese_window.window), "destroy",
      G_CALLBACK(on_cheese_window_close_cb), NULL);
  g_signal_connect(G_OBJECT(cheese_window.widgets.take_picture), "clicked",
      G_CALLBACK(pipeline_button_clicked), PipelinePhoto);
  g_signal_connect(cheese_window.widgets.screen, "expose-event",
      G_CALLBACK(expose_cb), NULL);
  g_signal_connect(G_OBJECT(cheese_window.widgets.button_effects), "clicked",
      G_CALLBACK(window_change_effect), PipelinePhoto);

  gtk_widget_show_all(cheese_window.window);
  gtk_main();

  return EXIT_SUCCESS;
}
