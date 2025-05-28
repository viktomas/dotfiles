# taken from https://github.com/day50-dev/Zummoner
# MIT License https://github.com/day50-dev/Zummoner/blob/main/LICENSE
# Copyright (c) 2025 DAY50

function zummoner
    set -l QUESTION (commandline)
    set -l PROMPT "
You are an experienced Linux engineer with expertise in all Linux
commands and their
functionality across different Linux systems.

Given a task, generate a single command or a pipeline
of commands that accomplish the task efficiently.
This command is to be executed in the current shell, fish.
For complex tasks or those requiring multiple
steps, provide a pipeline of commands.
Ensure all commands are safe and prefer modern ways. For instance,
homectl instead of adduser, ip instead of ifconfig, systemctl, journalctl, etc.
Make sure that the command flags used are supported by the binaries
usually available in the current system or shell.
If a command is not compatible with the
system or shell, provide a suitable alternative.

The system information is: (uname -a) (generated using: uname -a).
The user is $USER. Use sudo when necessary

Create a command to accomplish the following task: $QUESTION

If there is text enclosed in paranthesis, that's what ought to be changed

Output only the command as a single line of plain text, with no
quotes, formatting, or additional commentary. Do not use markdown or any
other formatting. Do not include the command into a code block.
Don't include the shell itself (bash, zsh, etc.) in the command.
"
    set -l model ""

    if test -r "$HOME/$config/io.datasette.llm/default_model.txt"
        set model (cat "$HOME/$config/io.datasette.llm/default_model.txt")
    else
        set model (llm models default)
    end

    commandline "$QUESTION ... $model"
    commandline -f repaint

    set -l response (llm "$PROMPT")
    set -l COMMAND (echo "$response" | sed 's/```//g' | tr -d '\n')

    if test -n "$COMMAND"
        commandline -r "$COMMAND"
        commandline -C (string length "$COMMAND")
    else
        commandline -r "$QUESTION ... no results"
    end
end
