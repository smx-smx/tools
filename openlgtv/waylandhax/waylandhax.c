#define _GNU_SOURCE
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include <unistd.h>
#include <dlfcn.h>

#include <wayland-webos-shell-client-protocol.h>

#define TYPEOF(src) __typeof__(src)
#define TYPEOF_ST(st, memb) __typeof__ (((st *)0)->memb)

struct wl_object {
	const struct wl_interface *interface;
	const void *implementation;
	uint32_t id;
};

static struct wl_webos_shell *_webos_shell = NULL;
static bool _dyn_initialized = false;
static unsigned _webos_surfaces_count = 0;
static struct wl_registry_listener _wl_registry_listeners = { NULL, NULL };

static TYPEOF_ST(struct wl_registry_listener, global)
	_user_registry_global_fn = NULL;

static TYPEOF(wl_proxy_add_listener)
	*_real_wl_proxy_add_listener = NULL;

static TYPEOF(wl_proxy_marshal_array_constructor_versioned)
	*_real_wl_proxy_marshal_array_constructor_versioned = NULL;

static struct wl_interface *wl_proxy_interface(struct wl_proxy *proxy){
	if(proxy == NULL) return NULL;
	// proxy->object -- const struct wl_interface *interface;
	return *(struct wl_interface **)proxy;
}

static const char *wl_proxy_name(struct wl_proxy *proxy){
	if(proxy == NULL) return NULL;

	struct wl_interface *intf = wl_proxy_interface(proxy);
	if(!intf) return NULL;

	return intf->name;
}

#define CHECK(v) ({ \
	void *v_=(v); \
	if(!v_){ puts("ERROR: " #v); exit(1); } \
	puts("OK: " #v); v_; \
})

static void dyn_init(){
	if(_dyn_initialized) return;

	_real_wl_proxy_add_listener = CHECK(dlsym(RTLD_NEXT, "wl_proxy_add_listener"));
	_real_wl_proxy_marshal_array_constructor_versioned = CHECK(dlsym(RTLD_NEXT, "wl_proxy_marshal_array_constructor_versioned"));

	_dyn_initialized = true;
}


static void
_registry_handle_global(
	void *data,
	struct wl_registry *registry,
	uint32_t id,
    const char *interface,
	uint32_t version
){
	printf("registry hook: %s\n", interface);
	if(!_webos_shell && strcmp(interface, "wl_webos_shell") == 0){
		_webos_shell = wl_registry_bind(registry, id, &wl_webos_shell_interface, 1);
		printf("webos_shell: %p\n", _webos_shell);
	}

	if(_user_registry_global_fn){
		_user_registry_global_fn(data, registry, id, interface, version);
	}
}

int
wl_proxy_add_listener(struct wl_proxy *proxy,
	void (**implementation)(void), void *data
){
	//printf("[+] wl_proxy_add_listener\n");
	
	const char *name = wl_proxy_name(proxy);
	if(name == NULL || strcmp(name, "wl_registry") != 0){
		return _real_wl_proxy_add_listener(proxy, implementation, data);
	}

	struct wl_registry_listener *registry_listener = (struct wl_registry_listener *)implementation;

	puts("HOOK REGISTRY LISTENER");

	// if the client is updating the listener (and it's not trying to re-register our hook)
	if(_user_registry_global_fn != registry_listener->global
	&& _user_registry_global_fn != &_registry_handle_global){
		// save original pfn
		_user_registry_global_fn = registry_listener->global;
	}
		
	printf("prev: %p, new: %p\n", _user_registry_global_fn, registry_listener->global);
	
	// hook the global listener
	_wl_registry_listeners.global = &_registry_handle_global;
	_wl_registry_listeners.global_remove = registry_listener->global_remove;

	return _real_wl_proxy_add_listener(proxy, (void (**)(void))&_wl_registry_listeners, data);
}

static void webos_surface_attach(struct wl_surface *surface){
	printf("attaching surface %d to webos surface\n", _webos_surfaces_count++);

	struct wl_webos_shell_surface *webos_shell_surface;
	webos_shell_surface = wl_webos_shell_get_shell_surface(_webos_shell, surface);

	char *app_id = getenv("APP_ID");
	char *display_id = getenv("DISPLAY_ID");

	wl_webos_shell_surface_set_property(webos_shell_surface, "appId",
		app_id ? app_id : "com.sample.waylandegl"
	);
	wl_webos_shell_surface_set_property(webos_shell_surface, "displayAffinity",
		display_id ? display_id : "0"
	);
}

struct argument_details {
	char type;
	int nullable;
};

static const char *
get_next_argument(const char *signature, struct argument_details *details)
{
	details->nullable = 0;
	for(; *signature; ++signature) {
		switch(*signature) {
		case 'i':
		case 'u':
		case 'f':
		case 's':
		case 'o':
		case 'n':
		case 'a':
		case 'h':
			details->type = *signature;
			return signature + 1;
		case '?':
			details->nullable = 1;
		}
	}
	details->type = '\0';
	return signature;
}

#define WL_CLOSURE_MAX_ARGS 20

static void wl_print_call(
	struct wl_proxy *proxy,
	uint32_t opcode,
	union wl_argument *args
){
	struct wl_interface *intf = wl_proxy_interface(proxy);
	struct wl_object *obj = (struct wl_object *)proxy;

	if(opcode >= intf->method_count) return;
	const struct wl_message *method = &intf->methods[opcode];
	const char *signature = method->signature;

	int i;
	const char *sig_iter;
	struct argument_details arg;

	printf("CALL %s.%s(id:%d,",
		intf->name, method->name,
		obj->id
	);	

	bool first = true;
	bool end = false;

	sig_iter = signature;
	for (i = 0; i < WL_CLOSURE_MAX_ARGS && !end; i++) {
		sig_iter = get_next_argument(sig_iter, &arg);

		if(arg.type == '\0'){
			end = true;
			continue;
		}

		if(first) first = false;
		else printf(",");

		switch(arg.type) {
		case 'i':
			printf("i32:%d", args[i].i);
			break;
		case 'u':
			printf("u32:%u", args[i].u);
			break;
		case 'f': {
			double d = wl_fixed_to_double(args[i].f);
			printf("flt:%.2lf", d);
			break;
		}
		case 's':
			printf("sz:\"%s\"", args[i].s);
			break;
		case 'o':
			// wl_object
			printf("obj:%p", args[i].o);
			break;
		case 'n':
			printf("new_id:%u", args[i].n);
			break;
		case 'a':
			printf("arr:[%d]", args[i].a->size);
			break;
		case 'h':
			printf("fd:%d", args[i].h);
			break;
		}
	}

	printf(")\n");
}

struct wl_proxy *
wl_proxy_marshal_array_constructor_versioned(struct wl_proxy *proxy,
					     uint32_t opcode,
					     union wl_argument *args,
					     const struct wl_interface *interface,
					     uint32_t version)
{
	const char *name = wl_proxy_name(proxy);
	struct wl_interface *intf = wl_proxy_interface(proxy);

	/*
	if(name != NULL){
		printf("[+] wl_proxy_marshal_array_constructor_versioned: %s (%u)\n", name, opcode);
	}
	*/
	if(intf != NULL){
		wl_print_call(proxy, opcode, args);
	}
	
	if(name != NULL){
		if(!strcmp(name, "wl_compositor")){
			if(opcode == WL_COMPOSITOR_CREATE_SURFACE){
				//puts("=== MAKING SURFACE");
				struct wl_surface *surface = (struct wl_surface *) _real_wl_proxy_marshal_array_constructor_versioned(proxy, opcode, args, interface, version);
				if(surface){
					//puts("WEBOSIZE");
					webos_surface_attach(surface);
				}
				return (struct wl_proxy *)surface;
			}
		}/* else if(!strcmp(name, "wl_shell_surface")){
			if(opcode == WL_SHELL_SURFACE_SET_FULLSCREEN){
				printf("=> WL_SHELL_SURFACE_SET_FULLSCREEN %d, forcing %d\n",
					args[0].i, WL_SHELL_SURFACE_FULLSCREEN_METHOD_DEFAULT
				);
				args[0].i = WL_SHELL_SURFACE_FULLSCREEN_METHOD_DEFAULT;
			}
		}*/
	}

	return _real_wl_proxy_marshal_array_constructor_versioned(proxy, opcode, args, interface, version);
}

void
__attribute__((constructor))
init(){
	dyn_init();
}
