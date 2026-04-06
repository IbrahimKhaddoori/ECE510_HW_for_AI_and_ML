out_path = Path("codefest/cf01/profiling/resnet18_profile.txt")
out_path.parent.mkdir(parents=True, exist_ok=True)

model = resnet18()

stats = summary(
    model,
    input_size=(1, 3, 224, 224),
    depth=10,
    col_names=("input_size", "output_size", "num_params", "mult_adds", "trainable"),
    row_settings=("var_names",),
    verbose=1,
)

text = str(stats)

out_path.write_text(text, encoding="utf-8")

print(text)
print(f"\nSaved to {out_path}")
