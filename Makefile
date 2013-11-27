# -*- Mode: makefile -*-

.PHONY: clean all debug release

# Required packages
PKGS = glib-2.0 gio-2.0 gio-unix-2.0 dbus-1

#
# Default target
#

all: debug release

#
# Sources
#

SRC = push-receive.c
GEN_SRC = org_ofono_manager.c org_ofono_push_notification.c \
  org_ofono_push_notification_agent.c

#
# Directories
#

SRC_DIR = .
BUILD_DIR = build
GEN_DIR = $(BUILD_DIR)
SPEC_DIR = dbus
DEBUG_BUILD_DIR = $(BUILD_DIR)/debug
RELEASE_BUILD_DIR = $(BUILD_DIR)/release

#
# Tools and flags
#

CC = $(CROSS_COMPILE)gcc
LD = $(CC)
DEBUG_FLAGS = -g
RELEASE_FLAGS = -O2
DEBUG_DEFS = -DDEBUG
RELEASE_DEFS =
WARNINGS = -Wall
CFLAGS = $(shell pkg-config --cflags $(PKGS)) -I$(GEN_DIR) -I.
DEBUG_CFLAGS = $(DEBUG_FLAGS) $(DEBUG_DEFS) $(CFLAGS) -MMD -MP
RELEASE_CFLAGS = $(RELEASE_FLAGS) $(RELEASE_DEFS) $(CFLAGS) -MMD -MP
LIBS = $(shell pkg-config --libs $(PKGS))

#
# Files
#

OFONO_MANAGER_SPEC = $(SPEC_DIR)/org.ofono.Manager.xml
OFONO_PUSH_SPEC = $(SPEC_DIR)/org.ofono.PushNotification.xml
PUSH_AGENT_SPEC = $(SPEC_DIR)/org.ofono.PushNotificationAgent.xml
SRC_FILES = \
  $(GEN_SRC:%=$(GEN_DIR)/%) \
  $(SRC:%=$(SRC_DIR)/%)
DEBUG_OBJS = \
  $(GEN_SRC:%.c=$(DEBUG_BUILD_DIR)/%.o) \
  $(SRC:%.c=$(DEBUG_BUILD_DIR)/%.o)
RELEASE_OBJS = \
  $(GEN_SRC:%.c=$(RELEASE_BUILD_DIR)/%.o) \
  $(SRC:%.c=$(RELEASE_BUILD_DIR)/%.o)

#
# Dependencies
#

DEPS = $(DEBUG_OBJS:%.o=%.d) $(RELEASE_OBJS:%.o=%.d)
ifneq ($(MAKECMDGOALS),clean)
ifneq ($(strip $(DEPS)),)
-include $(DEPS)
endif
endif

#
# Rules
#

EXE = push-receive
DEBUG_EXE = $(DEBUG_BUILD_DIR)/$(EXE)
RELEASE_EXE = $(RELEASE_BUILD_DIR)/$(EXE)

debug: $(DEBUG_EXE)

release: $(RELEASE_EXE) 

clean:
	rm -fr $(BUILD_DIR) $(SRC_DIR)/*~

$(GEN_DIR):
	mkdir -p $@

$(DEBUG_BUILD_DIR):
	mkdir -p $@

$(RELEASE_BUILD_DIR):
	mkdir -p $@

$(GEN_DIR)/org_ofono_manager.c: $(GEN_DIR) $(OFONO_MANAGER_SPEC)
	gdbus-codegen --generate-c-code $(@:%.c=%) $(OFONO_MANAGER_SPEC)

$(GEN_DIR)/org_ofono_push_notification.c: $(GEN_DIR) $(OFONO_PUSH_SPEC)
	gdbus-codegen --generate-c-code $(@:%.c=%) $(OFONO_PUSH_SPEC)

$(GEN_DIR)/org_ofono_push_notification_agent.c: $(GEN_DIR) $(PUSH_AGENT_SPEC)
	gdbus-codegen --generate-c-code $(@:%.c=%) $(PUSH_AGENT_SPEC)

$(DEBUG_EXE): $(DEBUG_BUILD_DIR) $(DEBUG_OBJS)
	$(LD) $(DEBUG_FLAGS) $(DEBUG_OBJS) $(LIBS) -o $@

$(RELEASE_EXE): $(RELEASE_BUILD_DIR) $(RELEASE_OBJS)
	$(LD) $(RELEASE_FLAGS) $(RELEASE_OBJS) $(LIBS) -o $@
	strip $@

$(DEBUG_BUILD_DIR)/%.o : $(SRC_DIR)/%.c
	$(CC) -c $(WARNINGS) $(DEBUG_CFLAGS) -MF"$(@:%.o=%.d)" $< -o $@

$(RELEASE_BUILD_DIR)/%.o : $(SRC_DIR)/%.c
	$(CC) -c $(WARNINGS) $(RELEASE_CFLAGS) -MF"$(@:%.o=%.d)" $< -o $@

$(DEBUG_BUILD_DIR)/%.o : $(GEN_DIR)/%.c
	$(CC) -c $(DEBUG_CFLAGS) -MF"$(@:%.o=%.d)" $< -o $@

$(RELEASE_BUILD_DIR)/%.o : $(GEN_DIR)/%.c
	$(CC) -c $(RELEASE_CFLAGS) -MF"$(@:%.o=%.d)" $< -o $@
