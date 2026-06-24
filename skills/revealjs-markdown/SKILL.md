---
name: revealjs-markdown
description: user wants to create markdown presentation with revealjs
---

## General rules

To create a reveal.js presentation Markdown, you specify the  output format in the YAML metadata of your document.
You can create a slide show broken up into sections by using the # and ## heading tags; you can also create a new slide without a header using a horizontal rule (---). For example, here is a simple slide show:

```md
---
title: "Habits"
author: John Doe
date: March 22, 2005
---

# In the morning

## Getting up

- Turn off alarm
- Get out of bed

## Breakfast

- Eat eggs
- Drink coffee

# In the evening

## Dinner

- Eat spaghetti
- Drink wine

## Going to sleep

- Get in bed
- Count sheep
```

## Appearance and style

There are several options that control the appearance of reveal.js presentations:

theme specifies the theme to use for the presentation (available themes are "default", "simple", "sky", "beige", "serif", "solarized", "blood", "moon", "night", "black", "league", and "white").

highlight specifies the syntax highlighting style. Supported styles include "default", "tango", "pygments", "kate", "monochrome", "espresso", "zenburn", and "haddock". Pass null to prevent syntax highlighting.

center specifies whether you want to vertically center content on slides (this defaults to false).

smart indicates whether to produce typographically correct output, converting straight quotes to curly quotes, --- to em-dashes, -- to en-dashes, and ... to ellipses. Note that smart is enabled by default.

For example:

---
theme: sky
highlight: pygments
center: true
---

### Smaller text
If you need smaller text for certain paragraphs, you can enclose text in the <small> tag. For example:

<small>This sentence will appear smaller.</small>


##  Slide transitions
You can use the transition and background_transition options to specify the global default slide transition style:

transition specifies the visual effect when moving between slides. Available transitions are "default", "fade", "slide", "convex", "concave", "zoom" or "none".

background_transition specifies the background transition effect when moving between full page slides. Available transitions are "default", "fade", "slide", "convex", "concave", "zoom" or "none".

For example:

---
transition: fade
---
You can override the global transition for a specific slide by using the data-transition attribute. For example:

```
## Use a zoom transition {data-transition="zoom"}

## Use a faster speed {data-transition-speed="fast"}
```
You can also use different in and out transitions for the same slide. For example:

```
## Fade in, Slide out {data-transition="slide-in fade-out"}

## Slide in, Fade out {data-transition="fade-in slide-out"}
```


## Slide backgrounds

Slides are contained within a limited portion of the screen by default to allow them to fit any display and scale uniformly. You can apply full page backgrounds outside of the slide area by adding a data-background attribute to your slide header element. Four different types of backgrounds are supported: color, image, video, and iframe. Below are a few examples.

```
## CSS color background {data-background=#ff0000}

## Full size image background {data-background="background.jpeg"}

## Video background {data-background-video="background.mp4"}

## A background page {data-background-iframe="https://example.com"}
```

Backgrounds transition using a fade animation by default. This can be changed to a linear sliding transition by specifying the background-transition: slide. Alternatively, you can set data-background-transition on any slide with a background to override that specific transition.


## Slide IDs and classes
You can also target specific slides or classes of slice with custom CSS by adding IDs or classes to the slides headers within your document. For example, the following slide header

```
## Next Steps {#nextsteps .emphasized}
```

would enable you to apply CSS to all of its content using either of the following CSS selectors:

```
#nextsteps {
   color: blue;
}

.emphasized {
   font-size: 1.2em;
}
```

## Styling text spans
You can apply classes defined in your CSS file to spans of text by using a span tag. For example:

```
<span class="emphasized">Pay attention to this!</span>
```


