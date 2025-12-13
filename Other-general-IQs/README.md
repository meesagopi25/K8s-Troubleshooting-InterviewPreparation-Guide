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
kubectl get pods, check logs<img width="880" height="319" alt="image" src="https://github.com/user-attachments/assets/f21b9004-9737-4bc1-9de3-682c4913fd7a" />
