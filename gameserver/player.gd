extends Node

var navigation_agent = NavigationAgent3D.new()
var animationPlayer = AnimationPlayer.new()
var moving = false

@rpc("call_remote")
func rpc_set_moving(_target): pass

@rpc("call_remote")
func rpc_set_position(_authority_position): pass

@rpc("call_remote")
func rpc_key_acquired(_color): pass

@rpc("call_remote")
func rpc_entered_portal_range(): pass

@rpc("call_remote")
func rpc_exited_portal_range(): pass

@rpc("call_remote")
func rpc_attempt_portal_activation(): pass
