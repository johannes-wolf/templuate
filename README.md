# templuate
A tiny lua template engine.

## Template Syntax
```
<% lua code %>
{{ output insides text }}
```

## Example

```
<% for i=1,5 do %>
This is line {{i}}!
<% end %>
```

Outputs:
```
This is line 1!
This is line 2!
This is line 3!
This is line 4!
This is line 5!
```

## Options
- `-D <var=value>` Set variable `var` in the templates global scope
- `-L <var> <value...> \;` Set `var` to list of values
- `-i` Enable interactive mode, allows calling `input(prompt)` from templates
- `-o <file>` Output to file instead of stdout
- `FILE` Input file
