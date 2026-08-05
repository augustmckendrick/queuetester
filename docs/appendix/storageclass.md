# Verifying a default StorageClass

Some operations, such as deploying a remote (SSH-based) cluster, require the management cluster to have a default `StorageClass`.  Follow these steps:

1. If not already installed, install and configure a `StorageClass` provider of your choice. 

2. Make sure you see the default setting:

    ```bash
    kubectl get storageclass
    ```

    You should see a result such as:

    ```console { .no-copy }
    NAME                         PROVISIONER               RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
    mayastor-etcd-localpv        openebs.io/local          Delete          WaitForFirstConsumer   false                  2m2s
    openebs-hostpath (default)   openebs.io/local          Delete          WaitForFirstConsumer   false                  2m2s
    openebs-loki-localpv         openebs.io/local          Delete          WaitForFirstConsumer   false                  2m2s
    openebs-minio-localpv        openebs.io/local          Delete          WaitForFirstConsumer   false                  2m2s
    openebs-single-replica       io.openebs.csi-mayastor   Delete          Immediate              true                   2m2s
    ```

3. Create a test PVC:

    ```bash
    cat <<'EOF' | kubectl apply -f -
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: test-pvc
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
    EOF
    ```

4. Create a test pod:

    ```bash
    cat <<'EOF' | kubectl apply -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: test-pvc-pod
    spec:
      containers:
        - name: test
          image: busybox
          command: ["sh", "-c", "echo hello > /data/test.txt && sleep 3600"]
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: test-pvc
    EOF
    ```

5. Check the results:

    ```bash
    kubectl get pod test-pvc-pod
    kubectl get pvc test-pvc
    ```
    ```console { .no-copy }
    NAME           READY   STATUS    RESTARTS   AGE
    test-pvc-pod   1/1     Running   0          20s

    NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS       VOLUMEATTRIBUTESCLASS   AGE
    test-pvc   Bound    pvc-61b4dd8b-9bcc-48e3-9055-9f0f80ea9abd   1Gi        RWO            openebs-hostpath   <unset>                 36s
    ```

    You should see the PVC become `Bound`.

6. Finally, clean up the test:

    ```bash
    kubectl delete pod test-pvc-pod
    kubectl delete pvc test-pvc
    ```