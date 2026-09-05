/*
 * Odyssey car-dashboard demo — LVGL on the ILI9486 SPI panel (/dev/fb0)
 * with XPT2046 touch (/dev/input/eventN).
 *
 * This is a scaffold: a dark speedometer with an animated needle plus a
 * touch read-out, so you can confirm display + touch and then replace
 * build_dashboard() with the real UI.
 *
 * Env overrides:
 *   LV_VIDEO_CARD   framebuffer node       (default: /dev/fb0)
 *   LV_TOUCH_DEV    touch input event node (default: autodetect, else /dev/input/event1)
 */

#include <dirent.h>
#include <fcntl.h>
#include <linux/input.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

#include "lvgl/lvgl.h"

/* ---- tick source ---------------------------------------------------------- */
static uint32_t tick_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint32_t)(ts.tv_sec * 1000u + ts.tv_nsec / 1000000u);
}

/* ---- touch device autodetect ------------------------------------------------ */
static int has_abs_xy(const char *path)
{
    int fd = open(path, O_RDONLY | O_NONBLOCK);
    if (fd < 0) return 0;
    unsigned long absbits[(ABS_MAX / (8 * sizeof(long))) + 1];
    memset(absbits, 0, sizeof(absbits));
    int ok = 0;
    if (ioctl(fd, EVIOCGBIT(EV_ABS, sizeof(absbits)), absbits) >= 0) {
        ok = (absbits[ABS_X / (8 * sizeof(long))] >> (ABS_X % (8 * sizeof(long)))) & 1;
    }
    close(fd);
    return ok;
}

static const char *find_touch_dev(void)
{
    const char *env = getenv("LV_TOUCH_DEV");
    if (env && *env) return env;

    static char buf[64];
    DIR *d = opendir("/dev/input");
    if (d) {
        struct dirent *e;
        while ((e = readdir(d))) {
            if (strncmp(e->d_name, "event", 5) != 0) continue;
            snprintf(buf, sizeof(buf), "/dev/input/%s", e->d_name);
            if (has_abs_xy(buf)) { closedir(d); return buf; }
        }
        closedir(d);
    }
    return "/dev/input/event1";
}

/* ---- dashboard UI --------------------------------------------------------- */
static lv_obj_t *arc_speed;
static lv_obj_t *lbl_speed;
static lv_obj_t *lbl_touch;

static void touch_cb(lv_event_t *e)
{
    lv_indev_t *indev = lv_indev_active();
    if (!indev) return;
    lv_point_t p;
    lv_indev_get_point(indev, &p);
    lv_label_set_text_fmt(lbl_touch, "touch  %d, %d", (int)p.x, (int)p.y);
}

static void anim_cb(lv_timer_t *t)
{
    LV_UNUSED(t);
    static float phase = 0.0f;
    phase += 0.05f;
    int spd = (int)(110.0f + 110.0f * sinf(phase));   /* 0..220 sweep */
    lv_arc_set_value(arc_speed, spd);
    lv_label_set_text_fmt(lbl_speed, "%d", spd);
}

static void build_dashboard(void)
{
    lv_obj_t *scr = lv_screen_active();
    lv_obj_set_style_bg_color(scr, lv_color_hex(0x0a0a10), 0);
    lv_obj_remove_flag(scr, LV_OBJ_FLAG_SCROLLABLE);

    lv_obj_t *title = lv_label_create(scr);
    lv_label_set_text(title, "ODYSSEY");
    lv_obj_set_style_text_color(title, lv_color_hex(0x5b6b8c), 0);
    lv_obj_align(title, LV_ALIGN_TOP_MID, 0, 8);

    arc_speed = lv_arc_create(scr);
    lv_obj_set_size(arc_speed, 280, 280);
    lv_obj_center(arc_speed);
    lv_arc_set_rotation(arc_speed, 135);
    lv_arc_set_bg_angles(arc_speed, 0, 270);
    lv_arc_set_range(arc_speed, 0, 220);
    lv_arc_set_value(arc_speed, 0);
    lv_obj_remove_style(arc_speed, NULL, LV_PART_KNOB);
    lv_obj_remove_flag(arc_speed, LV_OBJ_FLAG_CLICKABLE);
    lv_obj_set_style_arc_width(arc_speed, 14, LV_PART_MAIN);
    lv_obj_set_style_arc_width(arc_speed, 14, LV_PART_INDICATOR);
    lv_obj_set_style_arc_color(arc_speed, lv_color_hex(0x1c2333), LV_PART_MAIN);
    lv_obj_set_style_arc_color(arc_speed, lv_color_hex(0x36c2ff), LV_PART_INDICATOR);

    lbl_speed = lv_label_create(scr);
    lv_label_set_text(lbl_speed, "0");
    lv_obj_set_style_text_color(lbl_speed, lv_color_hex(0xf0f4ff), 0);
    lv_obj_set_style_text_font(lbl_speed, &lv_font_montserrat_40, 0);
    lv_obj_align(lbl_speed, LV_ALIGN_CENTER, 0, -6);

    lv_obj_t *unit = lv_label_create(scr);
    lv_label_set_text(unit, "km/h");
    lv_obj_set_style_text_color(unit, lv_color_hex(0x8a97b3), 0);
    lv_obj_align(unit, LV_ALIGN_CENTER, 0, 30);

    lbl_touch = lv_label_create(scr);
    lv_label_set_text(lbl_touch, "touch  -, -");
    lv_obj_set_style_text_color(lbl_touch, lv_color_hex(0x4a5878), 0);
    lv_obj_align(lbl_touch, LV_ALIGN_BOTTOM_MID, 0, -6);

    lv_obj_add_event_cb(scr, touch_cb, LV_EVENT_PRESSING, NULL);
    lv_timer_create(anim_cb, 40, NULL);
}

/* ---- main --------------------------------------------------------------- */
int main(void)
{
    lv_init();
    lv_tick_set_cb(tick_ms);

    const char *fb = getenv("LV_VIDEO_CARD");
    lv_display_t *disp = lv_linux_fbdev_create();
    lv_linux_fbdev_set_file(disp, fb && *fb ? fb : "/dev/fb0");

    const char *tdev = find_touch_dev();
    LV_LOG_USER("car-dashboard: touch device = %s", tdev);
    lv_evdev_create(LV_INDEV_TYPE_POINTER, tdev);

    build_dashboard();

    for (;;) {
        lv_timer_handler();
        usleep(5000);
    }
    return 0;
}
