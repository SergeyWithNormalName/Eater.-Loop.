extends PointLight2D

void _process(float delta):
	# Поворачивает узел так, чтобы его ось X смотрела на курсор
	look_at(get_global_mouse_position())
	
