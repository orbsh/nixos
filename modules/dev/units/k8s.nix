{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes  # 包含 kubeadm, kubelet, kube-apiserver 等
    kubernetes-helm
  ];
}
