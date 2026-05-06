#!/bin/bash
set -euo pipefail

# Use the namespace where the deployment actually exists
NAMESPACE="secure-deploy-prod"
DEPLOYMENT="microservice-app"

echo "🚀 Solving Kubernetes Secure Deployment Challenge"

# Create ConfigMap
kubectl apply -n "$NAMESPACE" -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  app.properties: |
    server.port=8080
    app.environment=production
    log.level=info
  MAX_CONNECTIONS: "100"
  CACHE_TTL: "3600"
EOF

# Create Secret
kubectl apply -n "$NAMESPACE" -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  db-username: YWRtaW5fdXNlcg==
  db-password: U2VjdXJlUEBzc3cwcmQxMjM=
  api-key: MTIzNDU2Nzg5MGFiY2RlZg==
EOF

# Patch Deployment
kubectl patch deployment "$DEPLOYMENT" -n "$NAMESPACE" --type='merge' -p '
spec:
  template:
    spec:
      volumes:
        - name: app-config-volume
          configMap:
            name: app-config
      containers:
        - name: microservice-app
          volumeMounts:
            - name: app-config-volume
              mountPath: /etc/config
              readOnly: true
          env:
            - name: MAX_CONNECTIONS
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: MAX_CONNECTIONS
            - name: CACHE_TTL
              valueFrom:
                configMapKeyRef:
                  name: app-config
                  key: CACHE_TTL
            - name: DB_USERNAME
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: db-username
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: db-password
            - name: API_KEY
              valueFrom:
                secretKeyRef:
                  name: app-secrets
                  key: api-key
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "200m"
              memory: "256Mi"
'

kubectl rollout status deployment "$DEPLOYMENT" -n "$NAMESPACE"

echo "✅ Challenge completed successfully"
