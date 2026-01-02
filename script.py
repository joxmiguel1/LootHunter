from pathlib import Path
path = Path(\ Localization.lua\)
text = path.read_text(encoding='latin1')
text = text.replace('    L[\" "EMPTY_TITLE\] = CreateGradient(\Conquista" a la "niebla\, 0.208, 0.498, 0.09, 0.729, 0.925, 0.255)', '    L[\EMPTY_TITLE\] = CreateGradient(\Nunca" pierdas tu "BiS\, 0.208, 0.498, 0.09, 0.729, 0.925, 0.255)', 1)
text = text.replace('    L[\" "EMPTY_QUOTES\] = {\\n        \\\No" dejes que tus recompensas se oculten de "ti.\\\\n    }', '    L[\EMPTY_QUOTES\] = {\\n        \\\Apunta" a tus recompensas. Asegura el "bot¡n.\\\\n    }', 1)
