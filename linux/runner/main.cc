#include <stdlib.h>
#include "my_application.h"

int main(int argc, char** argv) {
  // Use xdg-desktop-portal for native file dialogs on Wayland (GNOME, etc.)
  setenv("GTK_USE_PORTAL", "1", 1);
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
