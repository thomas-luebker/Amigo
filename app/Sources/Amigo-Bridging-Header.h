#pragma once

// Swift-visible C bridge into the WinUAE core (implemented in UAEBridge.mm).
void ipaduae_insert_floppy(int drive, const char *path);
void ipaduae_eject_floppy(int drive);
void ipaduae_reset(int hard);
void ipaduae_send_key(int sdl_scancode, int pressed);
void ipaduae_restart_with_config(const char *configpath);
void ipaduae_set_tablet_runtime(int on);
void ipaduae_set_safe_area(int on);
void ipaduae_set_leds(int on);
void ipaduae_set_rtg_accel(int on);
void ipaduae_set_vsync(int on);
void ipaduae_pointer_hover(float nx, float ny);
void ipaduae_set_external_display(int on);
void ipaduae_mouse_button(int button, int pressed);
void ipaduae_set_pen_hover(int active);
void ipaduae_state_op(int slot, int save);
void ipaduae_set_controller(int port, int cd32, int autofire);
const char *ipaduae_controller_name(void);
