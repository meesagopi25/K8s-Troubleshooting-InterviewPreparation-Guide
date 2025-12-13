1. How do you rollback a bad deployment?
Answer:
	• View history:
kubectl rollout history deployment/myapp
	• Rollback to previous:
kubectl rollout undo deployment/myapp
	• Or to a specific revision:
kubectl rollout undo deployment/myapp --to-revision=5
	• Then verify:
		○ kubectl rollout status deployment/myapp
kubectl get pods, check logs
