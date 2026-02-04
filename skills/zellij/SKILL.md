---
name: zellij
description: modify zellij config
---

## Zellij layouts

The layout structure is nested under a global `layout` node.

Within it are several possible node types:

-   [`pane`](https://zellij.dev/documentation/creating-a-layout.html#panes) - the basic building blocks of the layout, can represent shells, commands, plugins or logical containers for other `pane`s.
-   [`tab`](https://zellij.dev/documentation/creating-a-layout.html#tabs) - represents a navigational Zellij tab and can contain `pane`s
-   [`pane_template`](https://zellij.dev/documentation/creating-a-layout.html#pane-templates) - define new nodes equivalent to `pane`s with additional attributes or parameters.
-   [`tab_template`](https://zellij.dev/documentation/creating-a-layout.html#tab-templates) - define new nodes equivalent to `tab`s with additional attributes or parameters.

### [Panes](https://zellij.dev/documentation/creating-a-layout.html#panes)

`pane` nodes are the basic building blocks of a layout.

They could represent standalone panes:

`layout {     pane // panes can be bare     pane command="htop" // panes can have arguments on the same line     pane {         // panes can have arguments inside child-braces         command "exa"         cwd "/"     }     pane command="ls" { // or a mixture of same-line and child-braces arguments         cwd "/"     } }`

They could also represent logical containers:

`layout {     pane split_direction="vertical" {         pane         pane     } }`

**Note**: if panes represent logical containers, all their arguments should be specified on their title line.

#### [split\_direction](https://zellij.dev/documentation/creating-a-layout.html#split_direction)

`split_direction` is a pane argument that indicates whether its children will be laid out vertically or horizontally.

**Possible values:** `"vertical"` | `"horizontal"`

**Default value if omitted:** `"horizontal"`

eg.

`layout {     pane split_direction="vertical" {         pane         pane     }     pane {         // value omitted, will be layed out horizontally         pane         pane     } }`

**Note**: The `layout` node itself has a set value of "horizontal". It can be changed by adding a logical pane container:

`layout {     pane split_direction="vertical" {         pane         pane     } }`

#### [size](https://zellij.dev/documentation/creating-a-layout.html#size)

`size` is a pane argument that represents the fixed or percentage space taken up by this pane inside its logical container.

**Possible values:** quoted percentages (eg. "50%") | fixed values (eg. 1)

**Note**: specifying fixed values that are not `unselectable` plugins is **currently unstable** and might lead to unexpected behaviour when resizing or closing panes. Please see [this issue](https://github.com/zellij-org/zellij/issues/1758).

eg.

`layout {     pane size=5     pane split_direction="vertical" {         pane size="80%"         pane size="20%"     }     pane size=4 }`

#### [borderless](https://zellij.dev/documentation/creating-a-layout.html#borderless)

`borderless` is a pane argument indicating whether a pane should have a frame or not.

**Possible values:** true | false

**Default value if omitted:** false

eg.

`layout {     pane borderless=true     pane {         borderless true     } }`

#### [focus](https://zellij.dev/documentation/creating-a-layout.html#focus)

`focus` is a pane argument indicating whether a pane should have focus on startup.

**Possible values:** true | false **Default value if omitted:** false

**Note**: specifying multiple panes with focus will result in the first one of them being focused.

eg.

`layout {     pane focus=true     pane {         focus true     } }`

#### [name](https://zellij.dev/documentation/creating-a-layout.html#name)

`name` is a string pane argument to change the default pane title.

**Possible values:** "a quoted string"

eg.

`layout {     pane name="my awesome pane"     pane {         name "my amazing pane"     } }`

#### [cwd](https://zellij.dev/documentation/creating-a-layout.html#cwd)

A pane can have a `cwd` argument, pointing to its Current Working Directory.

**Possible values:** "/path/to/some/folder", "relative/path/to/some/folder"

**Note**: If the `cwd` is a relative path, it will be appended to its containers' cwd [read more about cwd composition](https://zellij.dev/documentation/creating-a-layout.html#cwd-composition)

eg.

`layout {     pane cwd="/"     pane {         command "git"         args "diff"         cwd "/path/to/some/folder"     } }`

#### [command](https://zellij.dev/documentation/creating-a-layout.html#command)

`command` is a string (path) to an executable that should be run in this pane instead of the default shell.

**Possible values:** "/path/to/some/executable" | "executable" (the latter should be accessible through PATH)

eg.

`layout {     pane command="htop"     pane {         command "/usr/bin/btm"     } }`

##### [args](https://zellij.dev/documentation/creating-a-layout.html#args)

A pane with a `command` can also have an `args` argument. This argument can include one or more strings that will be passed to the command as its arguments.

**Possible values:** "a" "series" "of" "quoted" "strings"

**Note**: `args` must be inside the `pane`'s child-braces and cannot be specified on the same line as the pane.

eg.

`layout {     pane command="tail" {         args "-f" "/path/to/my/logfile"     }      // Hint: include "quoted" shell arguments as a single argument:     pane command="bash" {         args "-c" "tail -f /path/to/my/logfile"     }  }`

##### [close\_on\_exit](https://zellij.dev/documentation/creating-a-layout.html#close_on_exit)

A pane with a `command` can also have a `close_on_exit` argument. If true, this pane will close immediately when its command exits - instead of the default behaviour which is to give the user a chance to re-run it with ENTER and see its exit status

**Possible values:** true | false

eg.

`layout {     pane command="htop" close_on_exit=true }`

##### [start\_suspended](https://zellij.dev/documentation/creating-a-layout.html#start_suspended)

A pane with a `command` can also have a `start_suspended` argument. If true, this pane will not immediately run the command on startup, but rather display a message inviting the user to press `<ENTER>` to first run the command. It will then behave normally. This can be useful when starting a layout with lots of commands and not wanting all of them to immediately run.

**Possible values:** true | false

eg.

`layout {     pane command="ls" start_suspended=true }`

#### [edit](https://zellij.dev/documentation/creating-a-layout.html#edit)

`edit` is a string (path) to a file that will be opened using the editor specified in the `EDITOR` or `VISUAL` environment variables. This can alternatively also be specified using the `scrollback_editor` config variable.

**Possible values:** "/path/to/some/file" | "./relative/path/from/cwd"

**Note**: If the value is a relative path, it will be appended to its containers' cwd [read more about cwd composition](https://zellij.dev/documentation/creating-a-layout.html#cwd-composition)

eg.

`layout {     pane split_direction="vertical" {         pane edit="./git_diff_side_a"         pane edit="./git_diff_side_b"     } }`

#### [plugin](https://zellij.dev/documentation/creating-a-layout.html#plugin)

`plugin` is a pane argument the points to a Zellij plugin to load. Currently is is only possible to specify inside the child-braces of a pane followed by a URL `location` in quoted string.

**Possible values:** `zellij:internal-plugin` | `file:/path/to/my/plugin.wasm`

eg.

`layout {     pane {         plugin location="zellij:status-bar"     } }`

#### [stacked](https://zellij.dev/documentation/creating-a-layout.html#stacked)

If `true`, this pane property dictates that the children panes of this pane will be arranged in a stack.

In a stack of panes, all panes except one have just one line - showing their title (and their scroll and exit code when relevant). The focused pane among these is displayed normally as any other pane.

eg.

`layout {     pane stacked=true {         pane         pane         pane command="ls"         pane command="htop"         pane edit="src/main.rs"     } }`

#### [expanded](https://zellij.dev/documentation/creating-a-layout.html#expanded)

In the context of `stacked` panes, an `expanded` child will dictate that this pane in the stack should be the one expanded, rather than the lowest pane (the default).

eg.

`layout {     pane stacked=true {         pane         pane expanded=true         pane         pane     } }`

### [Floating Panes](https://zellij.dev/documentation/creating-a-layout.html#floating-panes)

A `floating_panes` node can be included either at the root of the layout or inside a `tab` node. Panes nested in this node will be floating, and can be given `x`, `y`, `width` and `height` properties.

eg.

`layout {     floating_panes {         pane         pane command="ls"         pane {             x 1             y "10%"             width 200             height "50%"         }     } }`

`pane` nodes inside a `floating_panes` can have all the properties regular `pane` nodes have, except for children nodes or other irrelevant properties (eg. `split_direction`). `pane_templates` for these panes must not include these properties either.

#### [`x`, `y`, `width`, `height`](https://zellij.dev/documentation/creating-a-layout.html#x-y-width-height)

These properties may be included inside floating `pane`s. They can be either a fixed number (characters from screen edge) or a percentage (recommended in case where the terminal window size is not known).

### [Tabs](https://zellij.dev/documentation/creating-a-layout.html#tabs)

`tab` nodes can optionally be used to start a layout with several tabs.

**Note**: all tab arguments should be specified on its title line. The child-braces are reserved for its child panes.

eg.

`layout {     tab // a tab with a single pane     tab {         // a tab with three horizontal panes         pane         pane         pane     }     tab name="my third tab" split_direction="vertical" {         // a tab with a name and two vertical panes         pane         pane     } }`

#### [split\_direction](https://zellij.dev/documentation/creating-a-layout.html#split_direction-1)

Tabs can have a `split_direction` just like `pane`s. This argument indicates whether the tab's children will be laid out vertically or horizontally.

**Possible values:** `"vertical"` | `"horizontal"`

**Default value if omitted:** `"horizontal"`

eg.

`layout {     tab split_direction="vertical" {         pane         pane     }     tab {         // if omitted, will be "horizontal" by default         pane         pane     } }`

#### [focus](https://zellij.dev/documentation/creating-a-layout.html#focus-1)

Tabs can have a `focus` just like `pane`s. This argument indicates whether a tab should have focus on startup.

**Possible values:** true | false

**Default value if omitted:** false

**Note**: only one tab can be focused.

eg.

`layout {     tab {         pane         pane     }     tab focus=true {         pane         pane     } }`

#### [name](https://zellij.dev/documentation/creating-a-layout.html#name-1)

Tabs can have a `name` just like `pane`s. This argument is a string to change the default tab title.

**Possible values:** "a quoted string"

eg.

`layout {     tab name="my awesome tab"     tab name="my amazing tab" {         pane     } }`

#### [cwd](https://zellij.dev/documentation/creating-a-layout.html#cwd-1)

Tabs can have a `cwd` just like `pane`s - pointing to their Current Working Directory. All panes in this tab will have this `cwd` prefixed to their own `cwd` (if they have one) or start in this `cwd` if they don't.

**Possible values:** "/path/to/some/folder", "relative/path/to/some/folder"

**Note**: If the `cwd` is a relative path, it will be appended to its containers' cwd [read more about cwd composition](https://zellij.dev/documentation/creating-a-layout.html#cwd-composition)

eg.

`layout {     tab name="my amazing tab" cwd="/tmp" {         pane // will have its cwd set to "/tmp"         pane cwd="foo" // will have its cwd set to "/tmp/foo"         pane cwd="/home/foo" // will have its cwd set to "/home/foo", overriding the tab cwd with its absolute path     } }`

#### [hide\_floating\_panes](https://zellij.dev/documentation/creating-a-layout.html#hide_floating_panes)

If set, all floating panes defined in this tab will be hidden on startup.

eg.

`tab name="Tab #1" hide_floating_panes=true {     pane     pane     floating_panes { // will start hidden         pane         pane     } }`

### [Templates](https://zellij.dev/documentation/creating-a-layout.html#templates)

Templates can be used avoid repetition when creating layouts. Each template has a name that should be used directly as a node name instead of "pane" or "tab".

#### [Pane Templates](https://zellij.dev/documentation/creating-a-layout.html#pane-templates)

Pane templates can be used to shorten pane attributes:

`layout {     pane_template name="htop" {         command "htop"     }     pane_template name="htop-tree" {         command "htop"         args "--tree"         borderless true     }     // the below will create a template with four panes     // the top and bottom panes running htop and the two     // middle panes running "htop --tree" without a pane frame     htop     htop-tree     htop-tree     htop }`

Pane templates with the `command` attribute can take the `args` and `cwd` of their consumers:

`layout {     pane_template name="follow-log" command="tail"     follow-log {         args "-f" "/tmp/my-first-log"     }     follow-log {         args "-f" "my-second-log"         cwd "/tmp"     } }`

**Note**: the above only works for direct consumers and not other templates.

Pane templates can be used as logical containers. In this case a special `children` node must be specified to indicate where the child panes should be inserted.

**Note**: the `children` node can be nested inside `pane`s but not inside other `pane_template`s.

`layout {     pane_template name="vertical-sandwich" split_direction="vertical" {         pane         children         pane     }     vertical-sandwich {         pane command="htop"     } }`

Pane templates can include other pane templates.

`layout {     pane_template name="vertical-sandwich" split_direction="vertical" {         pane         children         pane     }     pane_template name="vertical-htop-sandwich" {         vertical-sandwich {             pane command="htop"         }     }     pane_template name="vertical-htop-sandwich-below" split_direction="horizontal" {         children         vertical-htop-sandwich     }     vertical-htop-sandwich     vertical-htop-sandwich-below {         pane command="exa"     } }`

The `children` node should be thought of as a placeholder for the pane using this template.

This:

`layout {     pane_template name="my_template" {         pane         children         pane     }     my_template split_direction="vertical" {         pane         pane     } }`

Will be translated into this:

`layout {     pane {         pane         pane split_direction="vertical" {             pane             pane         }         pane     } }`

#### [Tab Templates](https://zellij.dev/documentation/creating-a-layout.html#tab-templates)

Tab templates, similar to pane templates, help avoiding repetition when defining tabs. Like `pane_templates` they can include a `children` block to indicate where their child panes should be inserted.

**Note**: for the sake of clarity, arguments passed to `tab_template`s can only be specified on their title line.

`layout {     tab_template name="ranger-on-the-side" {         pane size=1 borderless=true {             plugin location="zellij:compact-bar"         }         pane split_direction="vertical" {             pane command="ranger" size="20%"             children         }     }     ranger-on-the-side name="my first tab" split_direction="horizontal" {         pane         pane     }     ranger-on-the-side name="my second tab" split_direction="vertical" {         pane         pane     } }`

##### [Default Tab Template](https://zellij.dev/documentation/creating-a-layout.html#default-tab-template)

There is a special `default_tab_template` node that can be used just like a regular `tab_template` node, but that would apply to all `tab`s in the template as well as all new tabs opened in the session.

**Note**: the `default_tab_template` will not apply to tabs using other `tab_template`s.

**Another note**: if no `tab`s are specified, the whole layout is treated as a `default_tab_template`.

`layout {     default_tab_template {         // the default zellij tab-bar and status bar plugins         pane size=1 borderless=true {             plugin location="zellij:tab-bar"         }         children         pane size=2 borderless=true {             plugin location="zellij:status-bar"         }     }     tab // the default_tab_template     tab name="second tab" // the default_tab_template with a custom tab name     tab split_direction="vertical" { // the default_tab_template with three vertical panes between the plugins         pane         pane         pane     } }`

### [`new_tab_template`](https://zellij.dev/documentation/creating-a-layout.html#new_tab_template)

This is a logical tab-like node that will only be used as a blueprint to open new tabs. It can be useful when one would like to define a few initial tabs, but use a different template for opening new tabs.

### [`cwd` Composition](https://zellij.dev/documentation/creating-a-layout.html#cwd-composition)

When a relative `cwd` property is specified in a node, it is appended to its container node's cwd in the follwing order:

1.  `pane`
2.  `tab`
3.  [global cwd](https://zellij.dev/documentation/creating-a-layout.html#global-cwd)
4.  The `cwd` where the command was executed

eg.

`layout {     cwd "/hi"     tab cwd="there" {         pane cwd="friend" // opened in /hi/there/friend     } }`

### [Global `cwd`](https://zellij.dev/documentation/creating-a-layout.html#global-cwd)

The `cwd` property can also be specified globally on the `layout` node itself.

Doing this would make all panes in this layout start in this cwd unless they have an absolute path.

Eg.

`layout {     cwd "/home/aram/code/my-project"     pane cwd="src" // will be opened in /home/aram/code/my-project/src     pane cwd="/tmp" // absolute paths override the global cwd, this will be opened in /tmp     pane command="cargo" {         args "test"         // will be started in /home/aram/code/my-project     } }`


## # [Including Configuration in Layouts](https://zellij.dev/documentation/layouts-with-config.html#including-configuration-in-layouts)

Zellij layout files can include any configuration that can be defined in a Zellij [configuration file](https://zellij.dev/documentation/configuration.html).

Items in this configuration take precedence over items in the loaded Zellij configuration.

**Note:** These fields are ignored when loading a layout through the [`new-tab` action](https://zellij.dev/documentation/cli-actions.html#new-tab)

## [Example](https://zellij.dev/documentation/layouts-with-config.html#example)

```
layout {
    pane split_direction="vertical" {
        pane
        pane split_direction="horizontal" {
            pane
            pane
        }
    }
    pane size=1 borderless=true {
        plugin location="zellij:compact-bar"
    }
}
keybinds {
    shared {
        bind "Alt 1" { Run "git" "status"; }
        bind "Alt 2" { Run "git" "diff"; }
        bind "Alt 3" { Run "exa" "--color" "always"; }
    }
}
```

This layout includes a map of panes and UI to open, as well as some keybindings to quickly open new panes with your favorite commands.


## Example layouts

### Classic three pane with vertical root

```
layout {
    pane split_direction="vertical" {
        pane
        pane split_direction="horizontal" {
            pane
            pane
        }
    }
}
```

### Classic three panes with vertical root and compact status bar

```
layout {
    pane split_direction="vertical" {
        pane
        pane split_direction="horizontal" {
            pane
            pane
        }
    }
    pane size=1 borderless=true {
        plugin location="zellij:compact-bar"
    }
}
```

### Quick generic project explorer

```
layout {
    pane split_direction="vertical" {
        pane
        pane split_direction="horizontal" {
            pane command="exa" {
                args "--color" "always" "-l"
            }
            pane command="git" {
                args "log"
            }
        }
    }
}
```

### Basic Rust project
```
layout {
    pane split_direction="vertical" size="60%" {
        pane edit="src/main.rs"
        pane edit="Cargo.toml"
    }
    pane split_direction="vertical" size="40%" {
        pane command="cargo" {
            args "run"
            focus true
        }
        pane command="cargo" {
            args "test"
        }
    }
}
```

For convenience, here's a version that also loads Zellij's interface

```
layout {
    pane size=1 borderless=true {
        plugin location="zellij:tab-bar"
    }
    pane split_direction="vertical" size="60%" {
        pane edit="src/main.rs"
        pane edit="Cargo.toml"
    }
    pane split_direction="vertical" size="40%" {
        pane command="cargo" {
            args "run"
            focus true
        }
        pane command="cargo" {
            args "test"
        }
    }
    pane size=2 borderless=true {
        plugin location="zellij:status-bar"
    }
}

```

A more complex example (Zellij development)

Here's a layout used internally for Zellij development.

It can help on-board new developers by tying together related files and their tests, as well as useful plugins here and there.

```
layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }
    pane_template name="tests_under_files" {
        pane split_direction="horizontal" {
            children
            pane command="cargo" size="30%" {
                args "test"
            }
        }
    }
    tab_template name="strider_tab" {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        pane split_direction="Vertical" {
            pane size="15%" {
                // TODO: when we support sending CWD to plugins, this should start in ./zellij-derver
                plugin location="zellij:strider"
            }
            children
        }
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }
    strider_tab name="Server (root)" cwd="./zellij-server" focus=true {
        tests_under_files split_direction="vertical" {
            pane edit="./src/lib.rs"
            pane edit="./src/route.rs"
        }
    }
    tab name="Client (root)" cwd="./zellij-client" {
        tests_under_files split_direction="vertical" {
            pane edit="./src/lib.rs"
            pane edit="./src/input_handler.rs"
        }
    }
    tab name="Server (screen thread)" split_direction="vertical" cwd="./zellij-server/src" {
        pane edit="./screen.rs" name="SCREEN"
        pane edit="./tab/mod.rs" name="TAB"
        pane edit="./panes/terminal_pane.rs" name="TERMINAL PANE"
    }
    tab name="Server (pty thread)" split_direction="vertical" cwd="./zellij-server/src" {
        pane edit="./pty.rs" name="PTY"
        pane edit="./os_input_output.rs" name="OS_INPUT_OUTPUT"
    }
    tab name="Server (pane grids)" split_direction="horizontal" cwd="./zellij-server/src/panes" {
        pane split_direction="vertical" {
            pane edit="./tiled_panes/mod.rs" name="TILED PANES"
            pane edit="./tiled_panes/tiled_pane_grid.rs" name="TILED PANES - GRID"
            pane edit="./tiled_panes/pane_resizer.rs" name="TILED PANES - GRID - RESIZER"
        }
        pane split_direction="vertical" {
            pane edit="./floating_panes/mod.rs" name="FLOATING_PANES"
            pane edit="./floating_panes/floating_pane_grid.rs" name="FLOATING_PANES - GRID"
        }
    }
    tab name="Server (Terminal)" split_direction="horizontal" cwd="./zellij-server/src/panes" {
        pane split_direction="vertical" {
            pane edit="./terminal_pane.rs" name="TERMINAL PANE"
            pane edit="./grid.rs" name="GRID (ANSI PARSER)"
        }
        pane split_direction="vertical" {
            pane edit="./terminal_character.rs" name="TERMINAL CHARACTER"
            pane edit="./sixel.rs" name="SIXEL"
        }
    }
}

```



## When editing kdl files respect kdl language specification below

KDL is a node-oriented document language. Its niche and purpose overlaps with
XML, and as do many of its semantics.

This is the formal specification for KDL, including the intended data model and
the grammar.

The bulk of this document is dedicated to a long-form description of all
Components ({{components}}) of a KDL document.
There is also a much more terse
Grammar ({{full-grammar}}) at the end of the document that covers most of the
rules, with some semantic exceptions involving the data model.

KDL is designed to be easy to read _and_ easy to implement.

In this document, references to "left" or "right" refer to directions in the
_data stream_ towards the beginning or end, respectively; in other words,
the directions if the data stream were only ASCII text. They do not refer
to the writing direction of text, which can flow in either direction,
depending on the characters used.

### Components

#### Document

The toplevel concept of KDL is a Document. A Document is composed of zero or
more Nodes ({{node}}), separated by newlines, semicolons, and whitespace, and eventually
terminated by an EOF.

All KDL documents MUST be encoded in UTF-8 and conform to the specifications in
this document.

##### Example

The following is a document composed of two toplevel nodes:

~~~kdl
foo {
    bar
}
baz
~~~

#### Node

Being a node-oriented language means that the real core component of any KDL
document is the "node". Every node must have a name, which must be a
String ({{string}}).

The name may be preceded by a Type Annotation ({{type-annotation}}) to further
clarify its type, particularly in relation to its parent node. (For example,
clarifying that a particular `date` child node is for the _publication_ date,
rather than the last-modified date, with `(published)date`.)

Following the name are zero or more Arguments ({{argument}}) or
Properties ({{property}}), separated by either whitespace ({{whitespace}}) or a
slash-escaped line continuation ({{line-continuation}}). Arguments and Properties
may be interspersed in any order, much like is common with positional arguments
vs options in command line tools. Collectively, Arguments and Properties may be
referred to as "Entries".

Children ({{children-block}}) can be placed after the name and the optional
Entries, possibly separated by either whitespace or a
slash-escaped line continuation.

Arguments are ordered relative to each other and that order must be preserved in
order to maintain the semantics. Properties between Arguments do not affect
Argument ordering.

By contrast, Properties _SHOULD NOT_ be assumed to be presented in a given
order. Children ({{children-block}}) should be used if an order-sensitive
key/value data structure must be represented in KDL. Cf. JSON objects
preserving key order.

Nodes _MAY_ be prefixed with Slashdash ({{slashdash-comments}}) to "comment out"
the entire node, including its properties, arguments, and children, and make
it act as plain whitespace, even if it spreads across multiple lines.

Finally, a node is terminated by either a Newline ({{newline}}), a semicolon
(`;`), the end of its parent's child block (`}`) or the end of the file/stream
(an `EOF`).

##### Example

~~~kdl
// `foo` will have an Argument value list like `[1, 3]`.
foo 1 key=val 3 {
    bar
    (role)baz 1 2
}
~~~

#### Line Continuation

Line continuations allow Nodes ({{node}}) to be spread across multiple lines.

A line continuation is a `\` character followed by zero or more whitespace
items (including multiline comments) and an optional single-line comment. It
must be terminated by a Newline ({{newline}}) (including the Newline that is
part of single-line comments).

Following a line continuation, processing of a Node can continue as usual.

##### Example

~~~kdl
my-node 1 2 \  // comments are ok after \
        3 4    // This is the actual end of the Node.
~~~

#### Property

A Property is a key/value pair attached to a Node ({{node}}). A Property is
composed of a String ({{string}}), followed immediately by an equals sign (`=`, `U+003D`),
and then a Value ({{value}}).

Properties should be interpreted left-to-right, with rightmost properties with
identical names overriding earlier properties. That is:

~~~kdl
node a=1 a=2
~~~

In this example, the node's `a` value must be `2`, not `1`.

No other guarantees about order should be expected by implementers.
Deserialized representations may iterate over properties in any order and
still be spec-compliant.

Properties _MAY_ be prefixed with `/-` to "comment out" the entire token and
make it act as plain whitespace, even if it spreads across multiple lines.

#### Argument

An Argument is a bare Value ({{value}}) attached to a Node ({{node}}), with no
associated key. It shares the same space as Properties ({{property}}), and may be interleaved with them.

A Node may have any number of Arguments, which should be evaluated left to
right. KDL implementations _MUST_ preserve the order of Arguments relative to
each other (not counting Properties).

Arguments _MAY_ be prefixed with `/-` to "comment out" the entire token and
make it act as plain whitespace, even if it spreads across multiple lines.

##### Example

~~~kdl
my-node 1 2 3 a b c
~~~

#### Children Block

A children block is a block of Nodes ({{node}}), surrounded by `{` and `}`. They
are an optional part of nodes, and create a hierarchy of KDL nodes.

Regular node termination rules apply, which means multiple nodes can be
included in a single-line children block, as long as they're all terminated by
`;`.

##### Example

~~~kdl
parent {
    child1
    child2
}

parent { child1; child2 }
~~~

#### Value

A value is either: a String ({{string}}), a Number ({{number}}), a
Boolean ({{boolean}}), or Null ({{null}}).

Values _MUST_ be either Arguments ({{argument}}) or values of
Properties ({{property}}). Only String ({{string}}) values may be used as
Node ({{node}}) names or Property ({{property}}) keys.

Values (both as arguments and in properties) _MAY_ be prefixed by a single
Type Annotation ({{type-annotation}}).

#### Type Annotation

A type annotation is a prefix to any Node Name ({{node}}) or Value ({{value}}) that
includes a _suggestion_ of what type the value is _intended_ to be treated as,
or as a _context-specific elaboration_ of the more generic type the node name
indicates.

Type annotations are written as a set of `(` and `)` with a single
String ({{string}}) in it. It may contain Whitespace after the `(` and before
the `)`, and may be separated from its target by Whitespace.

KDL does not specify any restrictions on what implementations might do with
these annotations. They are free to ignore them, or use them to make decisions
about how to interpret a value.

Additionally, the following type annotations MAY be recognized by KDL parsers
and, if used, SHOULD interpret these types as follows:

##### Reserved Type Annotations for Numbers Without Decimals:

Signed integers of various sizes (the number is the bit size):

- `i8`
- `i16`
- `i32`
- `i64`
- `i128`

Unsigned integers of various sizes (the number is the bit size):

- `u8`
- `u16`
- `u32`
- `u64`
- `u128`

Platform-dependent integer types, both signed and unsigned:

- `isize`
- `usize`

##### Reserved Type Annotations for Numbers With Decimals:

IEEE 754 floating point numbers, both single (32) and double (64) precision:

- `f32`
- `f64`

IEEE 754-2008 decimal floating point numbers

- `decimal64`
- `decimal128`

##### Reserved Type Annotations for Strings:

- `date-time`: ISO8601 date/time format.
- `time`: "Time" section of ISO8601.
- `date`: "Date" section of ISO8601.
- `duration`: ISO8601 duration format.
- `decimal`: IEEE 754-2008 decimal string format.
- `currency`: ISO 4217 currency code.
- `country-2`: ISO 3166-1 alpha-2 country code.
- `country-3`: ISO 3166-1 alpha-3 country code.
- `country-subdivision`: ISO 3166-2 country subdivision code.
- `email`: RFC5322 email address.
- `idn-email`: RFC6531 internationalized email address.
- `hostname`: RFC1123 internet hostname (only ASCII segments)
- `idn-hostname`: RFC5890 internationalized internet hostname
  (only `xn--`-prefixed ASCII "punycode" segments, or non-ASCII segments)
- `ipv4`: RFC2673 dotted-quad IPv4 address.
- `ipv6`: RFC2373 IPv6 address.
- `url`: RFC3986 URI.
- `url-reference`: RFC3986 URI Reference.
- `irl`: RFC3987 Internationalized Resource Identifier.
- `irl-reference`: RFC3987 Internationalized Resource Identifier Reference.
- `url-template`: RFC6570 URI Template.
- `uuid`: RFC4122 UUID.
- `regex`: Regular expression. Specific patterns may be implementation-dependent.
- `base64`: A Base64-encoded string, denoting arbitrary binary data.
- `base85`: An [Ascii85](https://en.wikipedia.org/wiki/Ascii85)-encoded string, denoting arbitrary binary data.

##### Examples

~~~kdl
node (u8)123
node prop=(regex).*
(published)date "1970-01-01"
(contributor)person name="Foo McBar"
~~~

#### String

Strings in KDL represent textual UTF-8 Values ({{value}}). A String is either an
Identifier String ({{identifier-string}}) (like `foo`), a
Quoted String ({{quoted-string}}) (like `"foo"`)
or a Multi-Line String ({{multi-line-string}}).
Both Quoted and Multiline strings come in normal
and Raw String ({{raw-string}}) variants (like `#"foo"#`):

- Identifier Strings let you write short, "single-word" strings with a
  minimum of syntax
- Quoted Strings let you write strings "like normal", with whitespace and escapes.
- Multi-Line Strings let you write strings across multiple lines
  and with indentation that's not part of the string value.
- Raw Strings don't allow any escapes,
  allowing you to not worry about the string's content containing anything that
  might look like an escape.

Strings _MUST_ be represented as UTF-8 values.

Strings _MUST NOT_ include the code points for
disallowed literal code points ({{disallowed-literal-code-points}}) directly.
Quoted and Multi-Line Strings may include these code points as _values_
by representing them with their corresponding `\u{...}` escape.

#### Identifier String

An Identifier String (sometimes referred to as just an "identifier") is
composed of any [Unicode Scalar
Value](https://unicode.org/glossary/#unicode_scalar_value) other than
non-initial characters ({{non-initial-characters}}), followed by any number of
Unicode Scalar Values other than non-identifier
characters ({{non-identifier-characters}}).

A handful of patterns are disallowed, to avoid confusion with other values:

- idents that appear to start with a Number ({{number}}) (like `1.0v2` or
  `-1em`) or the "almost a number" pattern of a decimal point without a
  leading digit (like `.1`).
- idents that are the language keywords (`inf`, `-inf`, `nan`, `true`,
  `false`, and `null`) without their leading `#`.

Identifiers that match these patterns _MUST_ be treated as a syntax error; such
values can only be written as quoted or raw strings. The precise details of the
identifier syntax is specified in the Full Grammar in {{full-grammar}}.

##### Non-initial characters

The following characters cannot be the first character in an
Identifier String ({{identifier-string}}):

- Any decimal digit (0-9)
- Any non-identifier characters ({{non-identifier-characters}})

Additionally, the following initial characters impose limitations on subsequent
characters:

- the `+` and `-` characters can only be used as an initial character if
  the second character is _not_ a digit. If the second character is `.`, then
  the third character must _not_ be a digit.
- the `.` character can only be used as an initial character if
  the second character is _not_ a digit.

This allows identifiers to look like `--this` or `.md`, and removes the
ambiguity of having an identifier look like a number.

##### Non-identifier characters

The following characters cannot be used anywhere in a Identifier String ({{identifier-string}}):

- Any of `(){}[]/\"#;=`
- Any Whitespace ({{whitespace}}) or Newline ({{newline}}).
- Any disallowed literal code points ({{disallowed-literal-code-points}}) in KDL
  documents.

#### Quoted String

A Quoted String is delimited by `"` on either side of any number of literal
string characters except unescaped `"` and `\`.

Literal Newline ({{newline}}) characters can only be included
if they are Escaped Whitespace ({{escaped-whitespace}}),
which discards them from the string value.
Actually including a newline in the value requires using a newline escape sequence,
like `\n`,
or using a Multi-Line String ({{multi-line-string}})
which is actually designed for strings stretching across multiple lines.

Like Identifier Strings, Quoted Strings _MUST NOT_ include any of the
disallowed literal code-points ({{disallowed-literal-code-points}}) as code
points in their body.

Quoted Strings have a Raw String ({{raw-string}}) variant,
which disallows escapes.

##### Escapes

In addition to literal code points, a number of "escapes" are supported in Quoted Strings.
"Escapes" are the character `\` followed by another character, and are
interpreted as described in the following table:

| Name                          | Escape | Code Pt  |
|-------------------------------|--------|----------|
| Line Feed                     | `\n`   | `U+000A` |
| Carriage Return               | `\r`   | `U+000D` |
| Character Tabulation (Tab)    | `\t`   | `U+0009` |
| Reverse Solidus (Backslash)   | `\\`   | `U+005C` |
| Quotation Mark (Double Quote) | `\"`   | `U+0022` |
| Backspace                     | `\b`   | `U+0008` |
| Form Feed                     | `\f`   | `U+000C` |
| Space                         | `\s`   | `U+0020` |
| Unicode Escape                | `\u{(1-6 hex chars)}` | Code point described by hex characters, as long as it represents a [Unicode Scalar Value](https://unicode.org/glossary/#unicode_scalar_value) |
| Whitespace Escape             | See below | N/A |

###### Escaped Whitespace

In addition to escaping individual characters, `\` can also escape whitespace.
When a `\` is followed by one or more literal whitespace characters, the `\`
and all of that whitespace are discarded. For example,

~~~kdl
"Hello World"
~~~

and

~~~kdl
"Hello \    World"
~~~

are semantically identical. See whitespace ({{whitespace}})
and newlines ({{newline}}) for how whitespace is defined.

Note that only literal whitespace is escaped; whitespace escapes (`\n` and
such) are retained. For example, these strings are all semantically identical:

~~~kdl
"Hello\       \nWorld"

    "Hello\n\
    World"

"Hello\nWorld"

"""
  Hello
  World
  """
~~~

###### Invalid escapes

Except as described in the escapes table, above, `\` _MUST NOT_ precede any
other characters in a string.

#### Multi-line String

Multi-Line Strings support multiple lines with literal, non-escaped
Newlines. They must use a special multi-line syntax, and they automatically
"dedent" the string, allowing its value to be indented to a visually matching
level as desired.

A Multi-Line String is opened and closed by _three_ double-quote characters,
like `"""`.
Its first line _MUST_ immediately start with a Newline ({{newline}})
after its opening `"""`.
Its final line _MUST_ contain only whitespace
before the closing `"""`.
All in-between lines that contain non-newline, non-whitespace characters
_MUST_ start with _at least_ the exact same whitespace as the final line
(precisely matching codepoints, not merely counting characters or "size");
they may contain additional whitespace following this prefix. The lines in
between may contain unescaped `"` (but no unescaped `"""` as this would close
the string).

The value of the Multi-Line String omits the first and last Newline, the
Whitespace of the last line, and the matching Whitespace prefix on all
intermediate lines. The first and last Newline can be the same character (that
is, empty multi-line strings are legal).

In other words, the final line specifies the whitespace prefix that will be
removed from all other lines.

Whitespace-only lines (that is, lines containing only literal whitespace
characters, not including whitespace escapes like `\t`) always represent
empty lines in the string value, regardless of what whitespace they
contain (if any). They do not have to start with the same whitespace prefix
that other lines do; all characters on the line are ignored.

Multi-line Strings that do not immediately start with a Newline and whose final
`"""` is not preceded by optional whitespace and a Newline are illegal. This
also means that `"""` may not be used for a single-line String (e.g.
`"""foo"""`).

##### Newline Normalization

Literal Newline sequences in Multi-line Strings must be normalized to a single
`U+000A` (`LF`) during deserialization. This means, for example, that `CR LF`
becomes a single `LF` during parsing.

This normalization does not apply to non-literal Newlines entered using escape
sequences. That is:

~~~kdl
multi-line """
    \r\n[CRLF]
    foo[CRLF]
    """
~~~

becomes:

~~~kdl
single-line "\r\n\nfoo"
~~~

For clarity: this normalization applies to each individual Newline sequence.
That is, the literal sequence `CRLF CRLF` becomes `LF LF`, not `LF`.

##### Examples

###### Indented multi-line string

~~~kdl
multi-line """
        foo
    This is the base indentation
            bar
    """
~~~

This example's string value will be:

~~~
    foo
This is the base indentation
        bar
~~~

which is equivalent to

~~~kdl
"    foo\nThis is the base indentation\n        bar"
~~~

when written as a single-line string.

###### Shorter last-line indent

If the last line wasn't indented as far,
it won't dedent the rest of the lines as much:

~~~kdl
multi-line """
        foo
    This is no longer on the left edge
            bar
  """
~~~

This example's string value will be:

~~~
      foo
  This is no longer on the left edge
          bar
~~~

Equivalent to

~~~kdl
"      foo\n  This is no longer on the left edge\n          bar"
~~~

###### Empty lines

Empty lines can contain any whitespace, or none at all, and will be reflected as empty in the value:

~~~kdl
multi-line """
    Indented a bit

    A second indented paragraph.
    """
~~~

This example's string value will be:

~~~
Indented a bit.

A second indented paragraph.
~~~

Equivalent to

~~~kdl
"Indented a bit.\n\nA second indented paragraph."
~~~

###### Syntax errors

The following yield **syntax errors**:

~~~kdl
multi-line """can't be single line"""
~~~

~~~kdl
multi-line """
  closing quote with non-whitespace prefix"""
~~~

~~~kdl
multi-line """stuff
  """
~~~

~~~kdl
// Every line must share the exact same prefix as the closing line.
multi-line """[\n]
[tab]a[\n]
[space][space]b[\n]
[space][tab][\n]
[tab]"""
~~~

##### Interaction with Whitespace Escapes

Multi-line strings support the same mechanism for escaping whitespace as Quoted
Strings.

When processing a Multi-line String, implementations MUST dedent the string
_after_ resolving all whitespace escapes, but _before_ resolving other backslash
escapes. This means a whitespace escape that attempts to escape the final line's
newline and/or whitespace prefix can be invalid: if removing escaped whitespace
places the closing `"""` on a line with non-whitespace characters, this escape
is invalid.

For example, the following example is illegal:

~~~kdl
  """
  foo
  bar\
  """

  // equivalent to
  """
  foo
  bar"""
~~~

while the following example is allowed

~~~kdl
  """
  foo \
bar
  baz
  \   """

  // equivalent to
  """
  foo bar
  baz
  """
~~~

#### Raw String

Both Quoted ({{quoted-string}}) and Multi-Line Strings ({{multi-line-string}}) have
Raw String variants, which are identical in syntax except they do not support
`\`-escapes. This includes line-continuation escapes (`\` + `ws` collapsing to
nothing). They otherwise share the same properties as far as literal
Newline ({{newline}}) characters go, multi-line rules, and the requirement of
UTF-8 representation.

The Raw String variants are indicated by preceding the strings's opening quotes
with one or more `#` characters. The string is then closed by its normal closing
quotes, followed by a _matching_ number of `#` characters. This means that the
string may contain any combination of `"` and `#` characters other than its
closing delimiter (e.g., if a raw string starts with `##"`, it can contain `"`
or `"#`, but not `"##` or `"###`).

Like other Strings, Raw Strings _MUST NOT_ include any of the disallowed
literal code-points ({{disallowed-literal-code-points}}) as code points in their
body. Unlike with Quoted Strings, these cannot simply be escaped, and are thus
unrepresentable when using Raw Strings.

##### Example

~~~kdl
just-escapes #"\n will be literal"#
~~~

The string contains the literal characters `\n will be literal`.

~~~kdl
quotes-and-escapes ##"hello\n\r\asd"#world"##
~~~

The string contains the literal characters `hello\n\r\asd"#world`

~~~kdl
raw-multi-line #"""
    Here's a """
        multiline string
        """
    without escapes.
    """#
~~~

The string contains the value

~~~
Here's a """
    multiline string
    """
without escapes.
~~~

or equivalently,

~~~kdl
"Here's a \"\"\"\n    multiline string\n    \"\"\"\nwithout escapes."
~~~

as a Quoted String.

#### Number

Numbers in KDL represent numerical Values ({{value}}). There is no logical distinction in KDL
between real numbers, integers, and floating point numbers. It's up to
individual implementations to determine how to represent KDL numbers.

There are five syntaxes for Numbers: Keywords, Decimal, Hexadecimal, Octal, and Binary.

- All non-Keyword ({{keyword-numbers}}) numbers may optionally start with one of `-` or `+`, which determine whether they'll be positive or negative.
- Binary numbers start with `0b` and only allow `0` and `1` as digits, which may be separated by `_`. They represent numbers in radix 2.
- Octal numbers start with `0o` and only allow digits between `0` and `7`, which may be separated by `_`. They represent numbers in radix 8.
- Hexadecimal numbers start with `0x` and allow digits between `0` and `9`, as well as letters `A` through `F`, in either lower or upper case, which may be separated by `_`. They represent numbers in radix 16.
- Decimal numbers are a bit more special:
  - They have no radix prefix.
  - They use digits `0` through `9`, which may be separated by `_`.
  - They may optionally include a decimal separator `.`, followed by more digits, which may again be separated by `_`.
  - They may optionally be followed by `E` or `e`, an optional `-` or `+`, and more digits, to represent an exponent value.

In all cases where the above says that digits "may be separated by `_`",
this means that between any two digits, or after the digits, any number of
consecutive `_` characters can appear. Underscores are not allowed *before* the digits.
That is, `1___2` and `12____` are valid (and both equivalent to just `12`), but
`_12` is *not* a valid number (it will instead parse as an identifier string),
nor is `0x_1a` (it will simply be invalid).

Note that, similar to JSON and some other languages,
numbers without an integer digit (such as `.1`) are illegal.
They must be written with at least one integer digit, like `0.1`.
(These patterns are also disallowed from Identifier Strings ({{identifier-string}}), to avoid confusion.)

##### Keyword Numbers

There are three special "keyword" numbers included in KDL to accommodate the
widespread use of [IEEE 754](https://en.wikipedia.org/wiki/IEEE_754) floats:

- `#inf` - floating point positive infinity.
- `#-inf` - floating point negative infinity.
- `#nan` - floating point NaN/Not a Number.

To go along with this and prevent foot guns, the bare Identifier
Strings ({{identifier-string}}) `inf`, `-inf`, and `nan` are considered illegal
identifiers and should yield a syntax error.

The existence of these keywords does not imply that any numbers be represented
as IEEE 754 floats. These are simply for clarity and convenience for any
implementation that chooses to represent their numbers in this way.

#### Boolean

A boolean Value ({{value}}) is either the symbol `#true` or `#false`. These
_SHOULD_ be represented by implementation as boolean logical values, or some
approximation thereof.

##### Example

~~~kdl
my-node #true value=#false
~~~

#### Null

The symbol `#null` represents a null Value ({{value}}). It's up to the
implementation to decide how to represent this, but it generally signals the
"absence" of a value.

##### Example

~~~kdl
my-node #null key=#null
~~~

#### Whitespace

The following characters should be treated as non-Newline ({{newline}}) [white
space](https://www.unicode.org/Public/UCD/latest/ucd/PropList.txt):

| Name                      | Code Pt  |
| ------------------------- | -------- |
| Character Tabulation      | `U+0009` |
| Space                     | `U+0020` |
| No-Break Space            | `U+00A0` |
| Ogham Space Mark          | `U+1680` |
| En Quad                   | `U+2000` |
| Em Quad                   | `U+2001` |
| En Space                  | `U+2002` |
| Em Space                  | `U+2003` |
| Three-Per-Em Space        | `U+2004` |
| Four-Per-Em Space         | `U+2005` |
| Six-Per-Em Space          | `U+2006` |
| Figure Space              | `U+2007` |
| Punctuation Space         | `U+2008` |
| Thin Space                | `U+2009` |
| Hair Space                | `U+200A` |
| Narrow No-Break Space     | `U+202F` |
| Medium Mathematical Space | `U+205F` |
| Ideographic Space         | `U+3000` |

##### Single-line comments

Any text after `//`, until the next literal Newline ({{newline}}) is "commented
out", and is considered to be Whitespace ({{whitespace}}).

##### Multi-line comments

In addition to single-line comments using `//`, comments can also be started
with `/*` and ended with `*/`. These comments can span multiple lines. They
are allowed in all positions where Whitespace ({{whitespace}}) is allowed and
can be nested.

##### Slashdash comments

Finally, a special kind of comment called a "slashdash", denoted by `/-`, can
be used to comment out entire _components_ of a KDL document logically, and
have those elements not be included as part of the parsed document data.

Slashdash comments can be used before the following, including before their type
annotations, if present:

- A Node ({{node}}): the entire Node is treated as Whitespace, including all
  props, args, and children.
- An Argument ({{argument}}): the Argument value is treated as Whitespace.
- A Property ({{property}}) key: the entire property, including both key and value,
  is treated as Whitespace. A slashdash of just the property value is not allowed.
- A Children Block ({{children-block}}): the entire block, including all
  children within, is treated as Whitespace. Only other children blocks, whether
  slashdashed or not, may follow a slashdashed children block.

A slashdash may be be followed by any amount of whitespace, including newlines and
comments (other than other slashdashes), before the element that it comments out.

#### Newline

The following character sequences [should be treated as new
lines](https://www.unicode.org/versions/Unicode16.0.0/core-spec/chapter-5/#G41643):

| Acronym | Name                          | Code Pt             |
| ------- | ----------------------------- | ------------------- |
| CRLF    | Carriage Return and Line Feed | `U+000D` + `U+000A` |
| CR      | Carriage Return               | `U+000D`            |
| LF      | Line Feed                     | `U+000A`            |
| NEL     | Next Line                     | `U+0085`            |
| VT      | Vertical tab                  | `U+000B`            |
| FF      | Form Feed                     | `U+000C`            |
| LS      | Line Separator                | `U+2028`            |
| PS      | Paragraph Separator           | `U+2029`            |

Note that for the purpose of new lines, the specific sequence `CRLF` is
considered _a single newline_.

#### Disallowed Literal Code Points

The following code points may not appear literally anywhere in the document.
They may be represented in Strings (but not Raw Strings) using Unicode Escapes ({{escapes}}) (`\u{...}`,
except for non Unicode Scalar Value, which can't be represented even as escapes).

- The codepoints `U+0000-0008` or the codepoints `U+000E-001F` (various
  control characters).
- `U+007F` (the Delete control character).
- Any codepoint that is not a [Unicode Scalar
  Value](https://unicode.org/glossary/#unicode_scalar_value) (`U+D800-DFFF`).
- `U+200E-200F`, `U+202A-202E`, and `U+2066-2069`, the [unicode
  "direction control"
  characters](https://www.w3.org/International/questions/qa-bidi-unicode-controls)
- `U+FEFF`, aka Zero-width Non-breaking Space (ZWNBSP)/Byte Order Mark (BOM),
  except as the first code point in a document.

### Full Grammar

This is the full official grammar for KDL and should be considered
authoritative if something seems to disagree with the text above. The grammar
language syntax is defined in {{grammar-language}}.

~~~abnf
document := bom? version? nodes

// Nodes
nodes := (line-space* node)* line-space*

base-node := slashdash? type? node-space* string
    (node-space* (node-space | slashdash) node-prop-or-arg)*
    // slashdashed node-children must always be after props and args.
    (node-space* slashdash node-children)*
    (node-space* node-children)?
    (node-space* slashdash node-children)*
    node-space*
node := base-node node-terminator
final-node := base-node node-terminator?

// Entries
node-prop-or-arg := prop | value
node-children := '{' nodes final-node? '}'
node-terminator := single-line-comment | newline | ';' | eof

prop := string node-space* '=' node-space* value
value := type? node-space* (string | number | keyword)
type := '(' node-space* string node-space* ')'

// Strings
string := identifier-string | quoted-string | raw-string ¶

identifier-string :=
    (unambiguous-ident | signed-ident | dotted-ident)
    - disallowed-keyword-identifiers
unambiguous-ident :=
    (identifier-char - digit - sign - '.') identifier-char*
signed-ident :=
    sign ((identifier-char - digit - '.') identifier-char*)?
dotted-ident :=
    sign? '.' ((identifier-char - digit) identifier-char*)?
identifier-char :=
    unicode - unicode-space - newline - [\\/(){};\[\]"#=]
    - disallowed-literal-code-points
disallowed-keyword-identifiers :=
    'true' | 'false' | 'null' | 'inf' | '-inf' | 'nan'

quoted-string :=
    '"' single-line-string-body '"' |
    '"""' newline
    (multi-line-string-body newline)?
    (unicode-space | ws-escape)* '"""'
single-line-string-body := (string-character - newline)*
multi-line-string-body := (('"' | '""')? string-character)*
string-character :=
    '\\' (["\\bfnrts] |
    'u{' hex-unicode '}') |
    ws-escape |
    [^\\"] - disallowed-literal-code-points
ws-escape := '\\' (unicode-space | newline)+
hex-digit := [0-9a-fA-F]
hex-unicode := hex-digit{1, 6} - surrogate - above-max-scalar
surrogate := [0]{0, 2} [dD] [8-9a-fA-F] hex-digit{2}
//  U+D800-DFFF:         D   8          00
//                       D   F          FF
above-max-scalar = [2-9a-fA-F] hex-digit{5} |
    [1] [1-9a-fA-F] hex-digit{4}


raw-string := '#' raw-string-quotes '#' | '#' raw-string '#'
raw-string-quotes :=
    '"' single-line-raw-string-body '"' |
    '"""' newline
    (multi-line-raw-string-body newline)?
    unicode-space* '"""'
single-line-raw-string-body :=
    '' |
    (single-line-raw-string-char - '"')
        single-line-raw-string-char*? |
    '"' (single-line-raw-string-char - '"')
        single-line-raw-string-char*?
single-line-raw-string-char :=
    unicode - newline - disallowed-literal-code-points
multi-line-raw-string-body :=
    (unicode - disallowed-literal-code-points)*?

// Numbers
number := keyword-number | hex | octal | binary | decimal

decimal := sign? integer ('.' integer)? exponent?
exponent := ('e' | 'E') sign? integer
integer := digit (digit | '_')*
digit := [0-9]
sign := '+' | '-'

hex := sign? '0x' hex-digit (hex-digit | '_')*
octal := sign? '0o' [0-7] [0-7_]*
binary := sign? '0b' ('0' | '1') ('0' | '1' | '_')*

// Keywords and booleans.
keyword := boolean | '#null'
keyword-number := '#inf' | '#-inf' | '#nan'
boolean := '#true' | '#false'

// Specific code points
bom := '\u{FEFF}'
disallowed-literal-code-points :=
    See Table (Disallowed Literal Code Points)
unicode := Any Unicode Scalar Value
unicode-space := See Table
    (All White_Space unicode characters which are not `newline`)

// Comments
single-line-comment := '//' ^newline* (newline | eof)
multi-line-comment := '/*' commented-block
commented-block :=
    '*/' | (multi-line-comment | '*' | '/' | [^*/]+) commented-block
slashdash := '/-' line-space*

// Whitespace
ws := unicode-space | multi-line-comment
escline := '\\' ws* (single-line-comment | newline | eof)
newline := See Table (All Newline White_Space)
// Whitespace where newlines are allowed.
line-space := node-space | newline | single-line-comment
// Whitespace within nodes,
// where newline-ish things must be esclined.
node-space := ws* escline ws* | ws+

// Version marker
version :=
    '/-' unicode-space* 'kdl-version' unicode-space+ ('1' | '2')
    unicode-space* newline
~~~

#### Grammar language

The grammar language syntax is a combination of ABNF with some regex spice thrown in.
Specifically:

- Single quotes (`'`) are used to denote literal text. `\` within a literal
  string is used for escaping other single-quotes, for initiating unicode
  characters using hex values (`\u{FEFF}`), and for escaping `\` itself
  (`\\`).
- `*` is used for "zero or more", `+` is used for "one or more", and `?` is
  used for "zero or one". Per standard regex semantics, `*` and `+` are _greedy_;
  they match as many instances as possible without failing the match.
- `*?` (used only in raw strings) indicates a _non-greedy_ match;
  it matches as _few_ instances as possible without failing the match.
- `¶` is a _cut point_. It always matches and consumes no characters,
  but once matched, the parser is not allowed to backtrack past that point in the source.
  If a parser would rewind past the cut point, it must instead fail the overall parse,
  as if it had run out of options.
  (This is only used with the `raw-string` production,
  to ensure the first instance of the appropriate closing quote sequence
  is guaranteed to be the end of the raw string,
  rather than allowing it to potentially consume more of the document unexpectedly.)
- `()` can be used to group matches that must be matched together.
- `a | b` means `a or b`, whichever matches first. If multiple items are before
  a `|`, they are a single group. `a b c | d` is equivalent to `(a b c) | d`.
- `[]` are used for regex-style character matches, where any character between
  the brackets will be a single match. `\` is used to escape `\`, `[`, and
  `]`. They also support character ranges (`0-9`), and negation (`^`)
- `-` is used for "except for" or "minus" whatever follows it. For example,
  `a - 'x'` means "any `a`, except something that matches the literal `'x'`".
- The prefix `^` means "something that does not match" whatever follows it.
  For example, `^foo` means "must not match `foo`".
- A single definition may be split over multiple lines. Newlines are treated as
  spaces.
- `//` followed by text on its own line is used as comment syntax.
