#!/usr/bin/env bash

# Runs an integration test for the secondary analysis service. Spins up a local instance of Lira,
# sends in notifications to launch workflows and waits for them to succeed or fail.

# This script carries out the following steps:
# 1. Clone mint-deployment
# 2. Clone Lira if needed
# 3. Get pipeline-tools version
# 4. Build or pull Lira image
# 5. Get pipeline versions
# 6. Create config.json
# 7. Start Lira
# 8. Send in notification
# 9. Poll Cromwell for completion
# 10. Stop Lira

# The following parameters are required. 
# Versions can be a branch name, tag, or commit hash
#
# env
# The instance of Cromwell to use. When running from a PR, this will always be staging.
# When running locally, the developer can choose.
#
# lira_mode and lira_version
# The lira_mode param can be "local", "image" or "github".
# If "local" is specified, a local copy of the Lira code is used. In this case,
# lira_version should be the local path to the repo.
# 
# If "image" is specified, this script will pull and run
# a particular version of the Lira docker image specified by lira_version.
# If lira_version == "latest_released", then the script will scan the GitHub repo
# for the highest tagged version and try to pull an image with the same version.
# If lira_version == "latest_deployed", then the script will use the latest
# deployed version in env, specified in the deployment tsv. If lira_version is
# any other value, then it is assumed to be a docker image tag version and
# this script will attempt to pull that version.
#
# Note that in image mode, the Lira repo will still get cloned, but only to
# make use of the Lira config template file, in order to generate a config file
# to run Lira with.
#
# Running in "github" mode causes this script to clone the Lira repo and check
# out a specific branch specified by lira_version. If the branch does not exist,
# master will be used instead.
#
# pipeline_tools_mode and pipeline_tools_version
# These parameters determine where Lira will look for adapter WDLs.
# (pipeline-tools is also used as a Python library for Lira, but that version
# is controlled in Lira's Dockerfile).
# If pipeline_tools_mode == "local", then a local copy of the repo is used,
# with the path to the repo specified in pipeline_tools_version.
#
# If pipeline_tools_mode == "github", then the script configures Lira to read the
# wrapper WDLS from GitHub and to use branch pipeline_tools_version. If the branch
# does not exist, master will be used instead.
# If pipeline_tools_version is "latest_released", then the latest tagged release
# in GitHub will be used. If pipeline_tools_version is "latest_deployed" then
# the latest version from the deployment tsv is used.
#
# tenx_mode and tenx_version
# When tenx_mode == "local", this script will configure lira to use the 10x wdl
# in a local directory specified by tenx_version.
#
# When tenx_mode == "github", this script will configure lira to use the 10x wdl
# in the skylab repo, with branch specified by tenx_version. If the branch does
# not exist, master will be used instead.
# If tenx_version == "latest_deployed", then this script will find the latest
# wdl version in the mint deployment TSV and configure lira to read that version
# from GitHub. If tenx_version == "latest_released" then this script will use
# the latest tagged release in GitHub.
#
# ss2_mode and ss2_version
# The ss2_mode and ss2_version params work in the same way as tenx_mode and
# tenx_version.
#
# ss2_sub_id
# Smart-seq2 subscription id
#
# tenx_sub_id
# 10x subscription id
#
# vault_token
# Token for vault auth
#
# submit_wdl_dir
# Should be an empty string except when testing skylab, in which case we use
# "submit_stub/" so that we don't test submission, since it is not really
# necessary for skylab PRs.

printf "\nStarting integration test\n"
date +"%Y-%m-%d %H:%M:%S"

set -e

env=$1
lira_mode=$2
lira_version=$3
pipeline_tools_mode=$4
pipeline_tools_version=$5
tenx_mode=$6
tenx_version=$7
ss2_mode=$8
ss2_version=$9
tenx_sub_id=${10}
ss2_sub_id=${11}
vault_token=${12}
submit_wdl_dir=${13}
use_caas=${14:-""}
caas_collection_name=${15:-"lira-${env}-workflows"}

work_dir=$(pwd)
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

printf "\n\nenv: $env"
printf "\nlira_mode: $lira_mode"
printf "\nlira_version: $lira_version"
printf "\npipeline_tools_mode: $pipeline_tools_mode"
printf "\npipeline_tools_version: $pipeline_tools_version"
printf "\ntenx_mode: $tenx_mode"
printf "\ntenx_version: $tenx_version"
printf "\nss2_mode: $ss2_mode"
printf "\nss2_version: $ss2_version"
printf "\ntenx_sub_id: $tenx_sub_id"
printf "\nss2_sub_id: $ss2_sub_id"
printf "\nsubmit_wdl_directory: $submit_wdl_dir"
printf "\nuse_caas: $use_caas"
printf "\ncaas_collection_name: $caas_collection_name"

printf "\n\nWorking directory: $work_dir"
printf "\nScript directory: $script_dir"

function get_version {
  repo=$1
  version=$2
  base_url="https://api.github.com/repos/HumanCellAtlas/$repo"
  branches_url="$base_url/branches/$version"
  commits_url="$base_url/commits/$version"
  status_code=$(curl -s -o /dev/null -w "%{http_code}" "$branches_url")
  if [ "$status_code" != "200" ]; then
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "$commits_url")
  fi
  if [ "$status_code" != "200" ]; then
    # 1>&2 prints message to stderr so it doesn't interfere with return value
    printf "\n\nCouldn't find $repo branch or commit $version. Using master instead.\n" 1>&2
    echo "master"
  else
    echo "$version"
  fi
}

# 1. Clone mint-deployment
printf "\n\nCloning mint-deployment\n"
git clone git@github.com:HumanCellAtlas/mint-deployment.git
mint_deployment_dir=mint-deployment

# 2. Clone Lira if needed
if [ $lira_mode == "github" ] || [ $lira_mode == "image" ]; then
  printf "\n\nCloning lira\n"
  git clone git@github.com:HumanCellAtlas/lira.git
  cd lira
  lira_dir=$PWD
  printf "\nlira_dir: $lira_dir\n"
  if [ $lira_version == "latest_released" ]; then
    printf "\nDetermining latest release tag\n"
    lira_version=$(python $script_dir/get_latest_release.py --repo HumanCellAtlas/lira)
  elif [ $lira_version == "latest_deployed" ]; then
    printf "\nDetermining latest deployed version\n"
    lira_version=$(python $script_dir/current_deployed_version.py \
                    --component_name lira
                    --env $env \
                    --mint_deployment_dir $mint_deployment_dir)
  else
    lira_version=$(get_version lira $lira_version)
  fi
  printf "\nChecking out $lira_version\n"
  git checkout $lira_version
  cd $work_dir
elif [ $lira_mode == "local" ]; then
  printf "\n\nUsing Lira in dir: $lira_version\n"
  lira_dir=$lira_version
fi

# 3. Get pipeline-tools version
if [ $pipeline_tools_mode == "github" ]; then
  if [ $pipeline_tools_version == "latest_released" ]; then
    printf "\n\nDetermining latest released version of pipeline-tools\n"
    pipeline_tools_version=$(python $script_dir/get_latest_release.py --repo HumanCellAtlas/pipeline-tools)
  elif [ $pipeline_tools_version == "latest_deployed" ]; then
    printf "\n\nDetermining latest deployed version of pipeline-tools\n"
    pipeline_tools_version=$(python $script_dir/current_deployed_version.py \
                      --mint_deployment_dir $mint_deployment_dir \
                      --env $env \
                      --component_name pipeline_tools)
  else
    pipeline_tools_version=$(get_version pipeline-tools $pipeline_tools_version)
  fi
  printf "\nConfiguring Lira to use adapter wdls from pipeline-tools GitHub repo, version: $pipeline_tools_version\n"
  pipeline_tools_prefix="https://raw.githubusercontent.com/HumanCellAtlas/pipeline-tools/${pipeline_tools_version}"
elif [ $pipeline_tools_mode == "local" ]; then
  pipeline_tools_prefix="/pipeline-tools"
  pipeline_tools_dir=$pipeline_tools_version
  # Get absolute path to pipeline_tools_dir, required to mount it into docker container later
  cd $pipeline_tools_dir
  pipeline_tools_dir=$(pwd)
  cd $work_dir
  printf "\n\nConfiguring Lira to use adapter wdls in dir: $pipeline_tools_dir\n"
fi

# 4. Build or pull Lira image
if [ $lira_mode == "image" ]; then
  if [ $lira_version == "latest_released" ]; then
    printf "\n\nDetermining latest released version of Lira\n"
    lira_image_version=$(python $script_dir/get_latest_release.py --repo HumanCellAtlas/lira)
  elif [ $lira_version == "latest_deployed" ]; then
    printf "\n\nDetermining latest deployed version of Lira\n"
    lira_image_version=$(python $script_dir/current_deployed_version.py lira)
  else
    lira_image_version=$lira_version
  fi
  docker pull quay.io/humancellatlas/secondary-analysis-lira:$lira_image_version
elif [ $lira_mode == "local" ] || [ $lira_mode == "github" ]; then
  cd $lira_dir
  if [ $lira_mode == "local" ]; then
    lira_image_version=local
  elif [ $lira_mode == "github" ]; then
    lira_image_version=$lira_version
  fi
  printf "\n\nBuilding Lira version \"$lira_image_version\" from dir: $lira_dir\n"
  docker build -t quay.io/humancellatlas/secondary-analysis-lira:$lira_image_version .
  cd $work_dir
fi

# 5. Get analysis pipeline versions to use
if [ $tenx_mode == "github" ]; then
  if [ $tenx_version == "latest_released" ]; then
    printf "\n\nDetermining latest released version of 10x pipeline\n"
    tenx_version=$(python $script_dir/get_latest_release.py --repo HumanCellAtlas/skylab --tag_prefix 10x_v)
  elif [ $tenx_version == "latest_deployed" ]; then
    printf "\n\nDetermining latest deployed version of 10x pipeline\n"
    tenx_version=$(python $script_dir/current_deployed_version.py \
                      --mint_deployment_dir $mint_deployment_dir \
                      --env $env \
                      --component_name 10x)
  else
    tenx_version=$(get_version skylab $tenx_version)
  fi
  tenx_prefix="https://raw.githubusercontent.com/HumanCellAtlas/skylab/${tenx_version}"
  printf "\nConfiguring Lira to use 10x wdl from skylab Github repo, version: $tenx_version\n"
elif [ $tenx_mode == "local" ]; then
  tenx_dir=$tenx_version
  cd $tenx_dir
  tenx_dir=$(pwd)
  cd $work_dir
  tenx_prefix="/10x"
  printf "\n\nUsing 10x wdl in dir: $tenx_dir\n"
fi

if [ $ss2_mode == "github" ]; then
  if [ $ss2_version == "latest_released" ]; then
    printf "\n\nDetermining latest released version of ss2 pipeline\n"
    ss2_version=$(python $script_dir/get_latest_release.py --repo HumanCellAtlas/skylab --tag_prefix smartseq2_v)
  elif [ $ss2_version == "latest_deployed" ]; then
    printf "\n\nDetermining latest deployed version of ss2 pipeline\n"
    ss2_version=$(python $script_dir/current_deployed_version.py \
                      --mint_deployment_dir $mint_deployment_dir \
                      --env $env \
                      --component_name ss2)
  else
    ss2_version=$(get_version skylab $ss2_version)
  fi
  printf "\nConfiguring Lira to use ss2 wdl from skylab GitHub repo, version: $ss2_version\n"
  ss2_prefix="https://raw.githubusercontent.com/HumanCellAtlas/skylab/${ss2_version}"
elif [ $ss2_mode == "local" ]; then
  ss2_dir=$ss2_version
  cd $ss2_dir
  ss2_dir=$(pwd)
  cd $work_dir
  ss2_prefix="/ss2"
  printf "\n\nUsing ss2 wdl in dir: $ss2_dir\n"
fi

# 6. Create config.json
printf "\n\nCreating Lira config\n\n"

docker run -i --rm \
    -e INPUT_PATH=/working \
    -e OUT_PATH=/working \
    -e ENV=${env} \
    -e LIRA_VERSION=${lira_version} \
    -e USE_CAAS=${use_caas} \
    -e COLLECTION_NAME=${caas_collection_name} \
    -e PIPELINE_TOOLS_PREFIX=${pipeline_tools_prefix} \
    -e SS2_VERSION=${ss2_version} \
    -e SS2_PREFIX=${ss2_prefix} \
    -e SS2_SUBSCRIPTION_ID=${ss2_sub_id} \
    -e TENX_VERSION=${tenx_version} \
    -e TENX_PREFIX=${tenx_prefix} \
    -e TENX_SUBSCRIPTION_ID=${tenx_sub_id} \
    -e VAULT_TOKEN=${vault_token} \
    -e SUBMIT_WDL_DIR=${submit_wdl_dir} \
    -v $lira_dir/kubernetes:/working broadinstitute/dsde-toolbox:k8s \
    /usr/local/bin/render-ctmpl.sh -k /working/listener-config.json.ctmpl

# 7. Start Lira

# Check if an old container exists
printf "\n\nChecking for old container"
docker stop lira || echo "container already stopped"
docker rm -v lira || echo "container already removed"

printf "\n\nStarting Lira docker image\n"
if [ $pipeline_tools_mode == "local" ]; then
  mount_pipeline_tools="-v $pipeline_tools_dir:/pipeline-tools"
  printf "\nMounting pipeline_tools_dir: $pipeline_tools_dir\n"
fi
if [ $tenx_mode == "local" ]; then
  mount_tenx="-v $tenx_dir:/10x"
  printf "\nMounting tenx_dir: $tenx_dir\n"
fi
if [ $ss2_mode == "local" ]; then
  mount_ss2="-v $ss2_dir:/ss2"
  printf "\nMounting ss2_dir: $ss2_dir\n"
fi


if [ $use_caas ]; then
    docker run -i --rm \
        -e VAULT_TOKEN=$vault_token broadinstitute/dsde-toolbox vault read \
        -format=json \
        -field=value \
        secret/dsde/mint/$env/listener/caas-${env}-key.json > $lira_dir/kubernetes/caas_key.json

    docker run -d \
        -p 8080:8080 \
        -e listener_config=/etc/lira/listener-config.json \
        -e caas_key=/etc/lira/caas_key.json \
        -v $lira_dir/kubernetes/listener-config.json:/etc/lira/listener-config.json \
        -v $lira_dir/kubernetes/caas_key.json:/etc/lira/caas_key.json \
        --name=lira \
        $(echo "$mount_pipeline_tools" | xargs) \
        $(echo "$mount_tenx" | xargs) \
        $(echo "$mount_ss2" | xargs) \
        quay.io/humancellatlas/secondary-analysis-lira:$lira_image_version
else
    docker run -d \
        -p 8080:8080 \
        -e listener_config=/etc/lira/listener-config.json \
        -v $lira_dir/kubernetes/listener-config.json:/etc/lira/listener-config.json \
        --name=lira \
        $(echo "$mount_pipeline_tools" | xargs) \
        $(echo "$mount_tenx" | xargs) \
        $(echo "$mount_ss2" | xargs) \
        quay.io/humancellatlas/secondary-analysis-lira:$lira_image_version
fi

printf "\nWaiting for Lira to finish start up\n"
sleep 3

n=$(docker ps -f "name=lira" | wc -l)
if [ $n -lt 2 ]; then
    printf "\nLira container exited unexpectedly\n"
    exit 1
fi

set +e
function stop_lira_on_error {
  printf "\n\nStopping Lira\n"
  docker stop lira
  docker rm -v lira
  printf "\n\nTest failed!\n\n"
  exit 1
}
trap "stop_lira_on_error" ERR

# 8. Send in notifications
printf "\n\nGetting notification token\n"

notification_token=$(docker run -i --rm \
      -e VAULT_TOKEN=$vault_token \
      broadinstitute/dsde-toolbox \
      vault read -field=notification_token secret/dsde/mint/$env/listener/listener_secret)

printf "\n\nSending in notifications\n"
ss2_workflow_id=$(docker run --rm -v $script_dir:/app \
                    -e LIRA_URL="http://lira:8080/notifications" \
                    -e NOTIFICATION_TOKEN=$notification_token \
                    -e NOTIFICATION=/app/ss2_notification_dss_${env}.json \
                    --link lira:lira \
                    broadinstitute/python-requests /app/send_notification.py)

printf "\nss2_workflow_id: $ss2_workflow_id"

# 9. Poll for completion
printf "\n\nAwaiting workflow completion\n"

if [ $use_caas ]; then
    python $script_dir/await_workflow_completion.py \
      --workflow_ids $ss2_workflow_id \
      --workflow_names ss2 \
      --cromwell_url https://cromwell.caas-dev.broadinstitute.org \
      --caas_key $lira_dir/kubernetes/caas_key.json \
      --timeout_minutes 120
else
    export cromwell_user=$(docker run -i --rm \
        -e VAULT_TOKEN=$vault_token \
            broadinstitute/dsde-toolbox \
            vault read -field=cromwell_user secret/dsde/mint/$env/common/htpasswd)

    export cromwell_password=$(docker run -i --rm \
        -e VAULT_TOKEN=$vault_token \
        broadinstitute/dsde-toolbox \
        vault read -field=cromwell_password secret/dsde/mint/$env/common/htpasswd)

    python $script_dir/await_workflow_completion.py \
      --workflow_ids $ss2_workflow_id \
      --workflow_names ss2 \
      --cromwell_url https://cromwell.mint-$env.broadinstitute.org \
      --timeout_minutes 120
fi


# 10. Stop Lira
printf "\n\nStopping Lira\n"
docker stop lira
docker rm -v lira
printf "\n\nTest succeeded!\n\n"