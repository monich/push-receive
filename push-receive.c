/*
 * oFono push notification agent - connects to the first available modem,
 * waits for push notification, writes PDU to the file and exits.
 */
#include <gio/gio.h>
#include <stdio.h>
#include <stdlib.h>

/* Generated headers */
#include "org_ofono_manager.h"
#include "org_ofono_push_notification.h"
#include "org_ofono_push_notification_agent.h"

#define OFONO_SERVICE   "org.ofono"
#define AGENT_ROOT      "/push"
#define AGENT_PATH      AGENT_ROOT "/0"

static const char* fname = "push.pdu";

/* Error handler */
static void
err_exit(
    const char* prefix,
    GError* error) 
{
    if (error) {
        printf("%s: %s\n", prefix, error->message);
        g_error_free(error);
    } else {
        printf("%s\n", prefix);
    }
    exit(1);
}

/* org.ofono.PushNotificationAgent.ReceiveNotification handler */
static gboolean
push_notification_agent_receive_notification(
    OrgOfonoPushNotificationAgent* agent,
    GDBusMethodInvocation* call,
    GVariant* data,
    GHashTable* dict,
    GMainLoop* loop)
{
    gsize len = 0;
    const guint8* bytes = g_variant_get_fixed_array(data, &len, 1);
    FILE* out = fopen(fname, "wb");
    printf("Parameter type %s\n", g_variant_get_type_string(data));
    printf("Received push notification (%u bytes)\n", len);
    printf("Dictionary: %u entries\n", g_hash_table_size(dict));
    if (out) {
        if (fwrite(bytes, 1, len, out) == len) {
            printf("Wrote %s\n", fname);
        } else {
            printf("Failed to write %s\n", fname);
        }
        fclose(out);
    } else {
        printf("Can't open %s\n", fname);
    }
    org_ofono_push_notification_agent_complete_receive_notification(agent,call);
    g_main_loop_quit(loop);
    return TRUE;
}

/* org.ofono.PushNotificationAgent.Release handler */
static gboolean
push_notification_agent_release(
    OrgOfonoPushNotificationAgent* agent,
    GDBusMethodInvocation* call,
    GMainLoop* loop)
{
    printf("Received release\n");
    org_ofono_push_notification_agent_complete_release(agent, call);
    g_main_loop_quit(loop);
    return TRUE;
}

int main(int argc, char* argv[])
{
    GDBusConnection* bus;
    GError* err = NULL;
    GMainLoop* loop;
    GVariant* modems = NULL;
    OrgOfonoManager* mgr;

    if (argc > 1) fname = argv[1];

    g_type_init();
    loop = g_main_loop_new(NULL, FALSE);
    bus = g_bus_get_sync(G_BUS_TYPE_SYSTEM, NULL, &err);
    if (!bus) err_exit("Couldn't connect to system bus", err);

    /* Get the list of modems from org.ofono.Manager */
    mgr = org_ofono_manager_proxy_new_sync(bus, 0,
        OFONO_SERVICE, "/", NULL, &err);
    if (!mgr) err_exit("Can't connect to oFono manager", err);

    if (!org_ofono_manager_call_get_modems_sync(mgr, &modems, NULL, &err)) {
        err_exit("Error getting list of modems", err);
    }

    printf("%d modem(s) found\n", g_variant_n_children(modems));
    if (g_variant_n_children(modems) > 0) {
        OrgOfonoPushNotification* push;

        /* Path to the first modem */
        const char* modem_path =
            g_variant_get_string(
            g_variant_get_child_value(
            g_variant_get_child_value(modems,0),0), NULL);

        /* Register org.ofono.PushNotificationAgent with D-Bus */
        OrgOfonoPushNotificationAgent* agent =
            org_ofono_push_notification_agent_skeleton_new();
        printf("Using modem \"%s\"\n", modem_path);
        if (!g_dbus_interface_skeleton_export(
            G_DBUS_INTERFACE_SKELETON(agent), bus, AGENT_PATH, &err)) {
            err_exit("Can't export agent interface", err);
        }

        /* Connect the signals */
        g_signal_connect(agent, "handle-receive-notification",
            G_CALLBACK(push_notification_agent_receive_notification),
            loop);

        g_signal_connect(agent, "handle-release",
            G_CALLBACK(push_notification_agent_release),
            loop);

        /* Register push notification agent with oFono */
        push = org_ofono_push_notification_proxy_new_sync(bus, 0,
            OFONO_SERVICE, modem_path, NULL, &err);
        if (!push) {
            err_exit("Can't connect to push service", err);
        }
        if (!org_ofono_push_notification_call_register_agent_sync(push,
            AGENT_PATH, NULL, &err)) {
            err_exit("Can't register push notification agent", err);
        }

        /* And wait for the message */
        g_main_loop_run(loop);
        g_object_unref(agent);
        g_object_unref(push);
    }
    g_variant_unref(modems);
    g_object_unref(mgr);
    g_main_loop_unref(loop);
    exit (0);
}

/*
 * Local Variables:
 * mode: C
 * c-basic-offset: 4
 * indent-tabs-mode: nil
 * End:
 */
