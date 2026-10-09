// Virtual pointer for the nested dev session (never the host). Steps run in order:
//   m X Y    move to output-local X,Y        c        left click, r right click
//   d / u    left button down / up           w N      wheel N notches (+ = down)
//   s MS     sleep MS milliseconds
// The output size comes from VPOINTER_SIZE="WxH" (dev/pointer.sh sets it).
#include <linux/input-event-codes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <wayland-client.h>
#include "wlr-virtual-pointer-unstable-v1-client-protocol.h"

static struct wl_seat *seat;
static struct zwlr_virtual_pointer_manager_v1 *manager;

static void global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
    (void)data;
    if (strcmp(interface, wl_seat_interface.name) == 0 && !seat)
        seat = wl_registry_bind(registry, name, &wl_seat_interface, 1);
    else if (strcmp(interface, zwlr_virtual_pointer_manager_v1_interface.name) == 0)
        manager = wl_registry_bind(registry, name, &zwlr_virtual_pointer_manager_v1_interface, 1);
    (void)version;
}
static void global_remove(void *data, struct wl_registry *registry, uint32_t name) { (void)data; (void)registry; (void)name; }
static const struct wl_registry_listener listener = { global, global_remove };

static uint32_t now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint32_t)(ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
}
static void sleep_ms(long ms) {
    struct timespec ts = { ms / 1000, (ms % 1000) * 1000000 };
    nanosleep(&ts, NULL);
}

int main(int argc, char **argv) {
    unsigned width = 1920, height = 1080;
    const char *size = getenv("VPOINTER_SIZE");
    if (size) sscanf(size, "%ux%u", &width, &height);

    struct wl_display *display = wl_display_connect(NULL);
    if (!display) { fprintf(stderr, "vpointer: cannot connect to $WAYLAND_DISPLAY\n"); return 1; }
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &listener, NULL);
    wl_display_roundtrip(display);
    if (!manager) { fprintf(stderr, "vpointer: compositor lacks zwlr_virtual_pointer_manager_v1\n"); return 1; }
    struct zwlr_virtual_pointer_v1 *pointer = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager, seat);

    for (int i = 1; i < argc; i++) {
        const char *op = argv[i];
        if (strcmp(op, "m") == 0 && i + 2 < argc) {
            unsigned x = (unsigned)atoi(argv[++i]), y = (unsigned)atoi(argv[++i]);
            zwlr_virtual_pointer_v1_motion_absolute(pointer, now_ms(), x, y, width, height);
            zwlr_virtual_pointer_v1_frame(pointer);
        } else if (strcmp(op, "d") == 0 || strcmp(op, "u") == 0) {
            zwlr_virtual_pointer_v1_button(pointer, now_ms(), BTN_LEFT, op[0] == 'd');
            zwlr_virtual_pointer_v1_frame(pointer);
        } else if (strcmp(op, "c") == 0) {
            zwlr_virtual_pointer_v1_button(pointer, now_ms(), BTN_LEFT, 1);
            zwlr_virtual_pointer_v1_frame(pointer);
            wl_display_flush(display);
            sleep_ms(30);
            zwlr_virtual_pointer_v1_button(pointer, now_ms(), BTN_LEFT, 0);
            zwlr_virtual_pointer_v1_frame(pointer);
        } else if (strcmp(op, "r") == 0) {
            zwlr_virtual_pointer_v1_button(pointer, now_ms(), BTN_RIGHT, 1);
            zwlr_virtual_pointer_v1_frame(pointer);
            wl_display_flush(display);
            sleep_ms(30);
            zwlr_virtual_pointer_v1_button(pointer, now_ms(), BTN_RIGHT, 0);
            zwlr_virtual_pointer_v1_frame(pointer);
        } else if (strcmp(op, "w") == 0 && i + 1 < argc) {
            int notches = atoi(argv[++i]);
            int step = notches > 0 ? 1 : -1;
            for (int n = 0; n != notches; n += step) {
                zwlr_virtual_pointer_v1_axis_source(pointer, WL_POINTER_AXIS_SOURCE_WHEEL);
                zwlr_virtual_pointer_v1_axis_discrete(pointer, now_ms(), WL_POINTER_AXIS_VERTICAL_SCROLL,
                                                      wl_fixed_from_int(15 * step), step);
                zwlr_virtual_pointer_v1_frame(pointer);
                wl_display_flush(display);
                sleep_ms(40);
            }
        } else if (strcmp(op, "s") == 0 && i + 1 < argc) {
            wl_display_flush(display);
            sleep_ms(atol(argv[++i]));
        } else {
            fprintf(stderr, "vpointer: bad step '%s'\n", op);
            return 2;
        }
        wl_display_flush(display);
    }
    wl_display_roundtrip(display);
    zwlr_virtual_pointer_v1_destroy(pointer);
    wl_display_disconnect(display);
    return 0;
}
