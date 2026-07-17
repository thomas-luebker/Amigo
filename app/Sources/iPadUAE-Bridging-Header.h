#pragma once

// Swift-visible C bridge into the WinUAE core (implemented in UAEBridge.mm).
void ipaduae_insert_floppy(int drive, const char *path);
void ipaduae_eject_floppy(int drive);
void ipaduae_reset(int hard);
