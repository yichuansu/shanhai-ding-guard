class_name EventDef
extends Resource
## 奇遇：一段《山海经》原文加 2–3 个选项。

@export var id: StringName
@export var title: String = ""
## 原文摘录。
@export_multiline var source_text: String = ""
## 白话说明当下的处境。
@export_multiline var situation: String = ""
@export var options: Array[EventOption] = []
