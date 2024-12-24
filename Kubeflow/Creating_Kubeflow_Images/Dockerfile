# https://ngc.nvidia.com/catalog/containers/nvidia:tensorflow
FROM nvcr.io/nvidia/pytorch:22.11-py3 

# Start Jupyter up by default rather than a shell
ENTRYPOINT ["/bin/sh"]
CMD ["-c", "jupyter lab  --notebook-dir=/workspace --ip=0.0.0.0 --no-browser --allow-root --port=8888 --NotebookApp.token='' --NotebookApp.password='' --NotebookApp.allow_origin='*' --NotebookApp.base_url=${NB_PREFIX}"]
