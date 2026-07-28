#!/usr/bin/env nu

use qute.nu

def get-ctx [] {
    let f = [$nu.data-dir 'openai.db'] | path join
    open $f
    | query db "select baseurl, api_key, model_default as model from provider where active = 1"
    | first
}

export def main [--text] {
    let t = qute selected-text
    let t = if ($t | is-empty) {
        open -r $env.QUTE_TEXT
    } else {
        $t
    }

    let lang = "_: |-
        Chinese
        English
        French
        Spanish
        German
        Russian
        Arabic
        Janpanese
        Korean
    " | from yaml | get _ | qute select

    let sys = $"_: |-
        #### Goals
        - Translate the given text into the ($lang).
        - Ensure that the translation uses natural and idiomatic expressions in the target language.

        #### Constraints
        - The translation should maintain the original meaning and tone of the text.
        - The translated text should be grammatically correct and culturally appropriate.
        - Only provide the translated content without explanations
        - Content within markdown code blocks remains unchanged
        - If there are special symbols, keep them as they are
        - Do not enclose the translation result with quotes

        #### Attention
        - Pay attention to idioms and colloquialisms in the source text and find equivalent expressions in the target language.
        - Consider the context and cultural nuances to ensure the translation is accurate and natural.

        #### Output Format
        - Provide the translated text in Markdown format.
        - Include any notes or explanations if there are specific idiomatic expressions used.
    " | from yaml | get _

    let c = get-ctx
    let req = {
        model: $c.model
        messages: [
            {
                role: system
                content: $sys
            }
            {
                role: user
                content: $t
            }
        ]
        temperature: 0.5
    }

    let r = http post -e -t application/json --headers [
        Authorization $"Bearer ($c.api_key)"
    ] $"($c.baseurl)/chat/completions" $req

    $r
    | get -i choices.0.message.content
    | qute to-html $env.QUTE_TITLE
    | qute open-tab translate.html

    $env.QUTE_EXIT_CODE.SUCCESS
}
