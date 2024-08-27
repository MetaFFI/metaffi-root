param (
    [string]$arg1
)

wsl bash -c "source ~/.profile && source ~/.bashrc && echo \$PATH && cd /mnt/c/src/github.com/MetaFFI/ && scons $arg1 --config=force;"