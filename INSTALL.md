# Installing BRB-seq scripts on Alliance Canada

### Steps

1. [Installing of the scripts](#Installing-of-the-scripts)
    1. [Change directory to `project` folder](#Change-directory-to-project-folder)
    2. [Clone repository](#Clone-repository)
2. [Updating scripts](#Updating-scripts)
3. [Install dependencies](#Install-dependencies)
   1. [Install fqtk](#install-fqtk)

## Installing of the scripts

### Change directory to project folder

```shell
cd /project/def-bmartin/scripts
```

### Clone repository

```shell
git clone https://github.com/BenMartinLab/brbseq.git
```

## Updating scripts

Go to the brbseq scripts folder and run `git pull`.

```shell
cd /project/def-bmartin/scripts/brbseq
git pull
```

## Install dependencies

Move to brbseq scripts directory.

```shell
cd /project/def-bmartin/scripts/brbseq
```

### Install fqtk

https://github.com/fulcrumgenomics/fqtk

```shell
bash install-fqtk.sh
```

